#!/bin/bash
# This code will take a template file and change it according to the requirements in the integration-definitions repo

file=$1
integration=$2
if grep -q "ParameterGroups" "$file"; then
    yq eval '.Metadata."AWS::CloudFormation::Interface".ParameterGroups[0].Parameters += "IntegrationId"' -i $file
fi
if grep -q "ParameterLabels" "$file"; then
    yq eval --inplace '.Metadata."AWS::CloudFormation::Interface".ParameterLabels += {"IntegrationId": {"default": "Integration ID"}}' $file
fi

yq eval --inplace '.Parameters += {"IntegrationId": {"Type": "String",  "Description": "The integration ID to register."}}' $file

echo "  # Used as a bridge because CF doesn't allow for conditional depends on clauses.
  NonNotifierResourcesAreReady:
    Type: AWS::CloudFormation::WaitConditionHandle
    Metadata:" >> "$file"

resources=$(cat "$file" | yq '.Resources' | grep -e '^[a-zA-Z]' | sed 's/:$//') # return the resources in the template
no_condition_resource=()
while IFS= read -r resource; do
    if yq ".Resources[\"$resource\"] | has(\"Condition\")" "$file" | grep -q 'true'; then
        condition=$(yq ".Resources[\"$resource\"].Condition" "$file" | grep -oE '[^ ]+$')
        echo "      ${resource}Ready: !If [ $condition, !Ref ${resource}, \"\" ]" >> $file
    else
      no_condition_resource+=($resource)
    fi
done <<< "$resources"

echo "  IntegrationStatusNotifier:
    Type: Custom::IntegrationsServiceNotifier
    DependsOn:" >> $file

for resource2 in "${no_condition_resource[@]}"; do
  echo "      - $resource2" >> $file
done
echo "
    Properties:
      #      {{AWS_ACCOUNT_ID}} is replaced during the template synchronisation
      ServiceToken: !Sub \"arn:aws:lambda:\${AWS::Region}:{{AWS_ACCOUNT_ID}}:function:integrations-custom-resource-notifier\"
      IntegrationId: !Ref IntegrationId
      CoralogixDomain: !If
        - IsRegionCustomUrlEmpty
        - !Ref CustomDomain
        - !FindInMap [ CoralogixRegionMap, !Ref CoralogixRegion, LogUrl ]
      CoralogixApiKey: !Ref ApiKey

      # Parameters to track
      IntegrationNameField: !Ref \"AWS::StackName\"
      SubsystemField: !Ref SubsystemName
      ApplicationNameField: !Ref ApplicationName" >> $file

if [[ $integration == "s3" ]] || [[ $integration == "s3-sns" ]] || [[ $integration == "cloudtrail" ]] || [[ $integration == "cloudtrail-sns" ]] || [[ $integration == "vpc-flow-logs" ]]; then
  echo "      S3BucketNameField: !Ref S3BucketName" >> "$file"
fi
if [[ $integration == "s3-sns" ]] || [[ $integration == "cloudtrail-sns" ]]; then
  echo "      SNSTopicArnField: !Ref SNSTopicArn" >> "$file"
fi
if [[ $integration == "cloudwatch-logs" ]]; then
  echo "      CloudWatchLogGroupNameField: !Ref CloudWatchLogGroupName" >> "$file"
fi