workflow "Build and Push" {
  on = "push"
  resolves = [
    "wait cloudfront deployed",
    "build_site",
  ]
}

action "build_site" {
  uses = "repetitive/actions/hugo@master"
}

action "upload to s3" {
  uses = "actions/aws/cli@51b5c9b60da75d1d3f97ff91ed2e4efc19dd5474"
  args = "s3 cp ${HOME}/build_site/ s3://cyclic.cc/$GITHUB_SHA --recursive --acl public-read"
  secrets = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
  needs = ["build_site"]
}

action "update cloudfront" {
  uses = "actions/aws/cli@51b5c9b60da75d1d3f97ff91ed2e4efc19dd5474"
  needs = ["upload to s3"]
  secrets = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
  args = "cloudfront get-distribution-config --id $CF_ZONE_ID > distconfig_result.json; SLASH='/'; ORIGIN_PATH=$SLASH$GITHUB_SHA;sed 's,OriginPath\": \".*\",OriginPath\": \"'$ORIGIN_PATH'\",g' distconfig_result.json > temp_config.json; jq .DistributionConfig temp_config.json > updated_config.json; cat updated_config.json; aws cloudfront update-distribution --if-match $(jq .ETag --raw-output distconfig_result.json) --id $CF_ZONE_ID --distribution-config file://updated_config.json"
  env = {
    CF_ZONE_ID = "E1TRGMU2X297HL"
  }
}

action "wait cloudfront deployed" {
  uses = "actions/aws/cli@aba0951d3bb681880614bbf0daa29b4a0c9d77b8"
  needs = ["update cloudfront"]
  secrets = ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"]
  args = "cloudfront wait distribution-deployed --id $CF_ZONE_ID"
  env = {
    CF_ZONE_ID = "E1TRGMU2X297HL"
  }
}
