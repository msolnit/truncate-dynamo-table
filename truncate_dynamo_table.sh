#!/bin/bash

usage()
{
cat << EOF
usage: $0 options

This script deletes all the rows from a DynamoDB table.

OPTIONS:
   -h      Show this message
   -t      Table name
   -k      Key column name
   -p      AWS CLI profile name (optional)
   -r      Region (optional if your AWS CLI has a default region)
EOF
}

while getopts "t:k:p:r:h" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    t)
      TABLE=$OPTARG
      ;;
    k)
      KEY_COLUMN=$OPTARG
      ;;
    r)
      REGION=$OPTARG
      ;;
    p)
      PROFILE=$OPTARG
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

which jq > /dev/null
if [ $? -ne 0 ]; then
  echo "The jq utility must be installed to run this script."
  echo "See https://stedolan.github.io/jq/"
  exit 1
fi

which aws > /dev/null
if [ $? -ne 0 ]; then
  echo "The AWS CLI must be installed to run this script."
  echo "See https://aws.amazon.com/cli/"
  exit 1
fi

if [ -z "$TABLE" ]; then
  echo "Table name is required (use the -t parameter)."
  exit 1
fi
if [ -z "$KEY_COLUMN" ]; then
  echo "Key column name is required (use the -k parameter)."
  exit 1
fi

echo "Truncating table $TABLE in region $REGION..."

if [ -n "$PROFILE" ]; then
  AWS_CLI_ARGS="$AWS_CLI_ARGS --profile $PROFILE"
fi
if [ -n "$REGION" ]; then
  AWS_CLI_ARGS="$AWS_CLI_ARGS --region $REGION"
fi

KEY_JSON=$(aws $AWS_CLI_ARGS dynamodb scan --table-name $TABLE)
if [ $? -ne 0 ]; then
  echo "Table scan failed."
  exit 1
fi

KEY_LIST=$(echo "$KEY_JSON" | jq ".Items[].$KEY_COLUMN.S" | sed 's/\"//g')
if [ -z "$KEY_LIST" ]; then
  echo "Table is empty."
  exit 0
fi

KEY_COUNT=$(echo "$KEY_LIST" | wc -l)
echo "Deleting $KEY_COUNT key(s)."

echo "$KEY_LIST" | xargs -IID aws $AWS_CLI_ARGS dynamodb delete-item --table-name $TABLE --key "{ \"$KEY_COLUMN\": { \"S\": \"ID\" } }"
