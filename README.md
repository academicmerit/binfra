# binfra

Bash infrastructure lib with concise functions:

```
# NAME=VALUE ...

vpc::create
rds::create
fargate::create-cluster
fargate::create-execution-role

fargate::create-app $APP \
    $IMAGE \
    $PORT \
    $HEALTH_PATH \
    "$ENV_VARS" \
    "$SECRETS"
```

This will get `$APP` exposed to `https://$ENV-$APP.$PROJECT.$COMPANY_DOMAIN_NAME`

AWS layers supported at the moment:

```
    R53
   /   \
ELB     APIGW
 |        |    
Fargate  SAM*
 |
ECS  RDS
 |  /
 | /
VPC     \  |
 |       SSM
EC2    --IAM
```

Original [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html)
is concise enough, so no `lib/aws/sam` exists in `binfra`,
but `lib/aws/expose` provides function suitable for SAM + API Gateway integration:

```
expose::create-api-gw-domain-name \
    $ENV-$SAM_APP.$PROJECT.$COMPANY_DOMAIN_NAME \
    $SAM_STACK_NAME
```

## Install

`binfra` requires `import` and `shellcheck`:

```
sudo bash -c "
curl -sfLS https://import.pw > /usr/local/bin/import
chmod +x /usr/local/bin/import
snap install --channel=edge shellcheck || {
    echo 'Please do https://github.com/koalaman/shellcheck#installing'
}
"
```

Please copy [bin/install](bin/install?raw=true) template to your project
and tailor it for your needs

Please run `bin/install dev` to install `dev` env of your project into AWS cloud

## Uninstall

* Idea to convert this instruction to `bin/uninstall $ENV` script
  with confirmation dialog and pause to Ctrl+C
  has one big disadvantage: AWS CLI [requires](https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-vpc.html)
  deleting tons of associated resources manually,
  while AWS Web Console deletes a lot "by cascade" automatically and easily
* Open the links below in the given order, search for your `$PROJECT` name, select, delete
* https://console.aws.amazon.com/route53/v2/hostedzones - `$COMPANY_DOMAIN_NAME` - `$PROJECT`
* https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/fargate/tasks - Stop tasks
* https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/fargate/services - Delete
* https://console.aws.amazon.com/ecs/home?region=us-east-1#/taskDefinitions
    * Open task def, Select all, Actions - Deregister
* https://console.aws.amazon.com/apigateway/main/publish/domain-names?region=us-east-1
* https://console.aws.amazon.com/apigateway/main/apis?region=us-east-1
* https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks?filteringText=&filteringStatus=active&viewNested=true&hideStacks=false
* https://console.aws.amazon.com/rds/home?region=us-east-1#databases:
    * Modify, `[ ] Enable deletion protection`, `(*) Apply immediately`, Actions - Delete
* https://console.aws.amazon.com/rds/home?region=us-east-1#db-subnet-groups-list:
* https://console.aws.amazon.com/vpc/home?region=us-east-1#NatGateways:sort=natGatewayId
* https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers:sort=loadBalancerName
* https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#Addresses:
* https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#TargetGroups:
* https://console.aws.amazon.com/vpc/home?region=us-east-1#vpcs:sort=VpcId
* https://console.aws.amazon.com/systems-manager/parameters/?region=us-east-1&tab=Table
    * Select 10 parameters, Delete, repeat
* https://console.aws.amazon.com/iam/home?region=us-east-1#/roles
    * Roles starting on `$PROJECT` name only
* https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
    * `[x] Exact match`

## Bash

* To avoid bash issues, we will use the next tools and ideas
* [Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
    * We avoid `-o pipefail` because it breaks very useful things like
     `list-items | grep -q item || create-item`
* [ShellCheck](https://www.shellcheck.net/), added to `bin/test`
    * Read its [Gallery of bad code](https://github.com/koalaman/shellcheck#gallery-of-bad-code)
* Read [Bash cheatsheet](https://devhints.io/bash)
* How to return values from functions:
    * `return 0` means success
    * `return 1` raises an error
    * Simple functions that have no logging `echo`-s or third-party stdout inside
      can return a value via stdout, e.g. `VALUE=$(ssm::rand-str)`
    * More complex functions follow the bultin `read NAME NAME...` syntax
      to assign return values to given NAMEs:
      `expose::create-lb LB_SECGROUP_ID TARGET_GROUP_ARN...`
* To avoid `"$QUOTING" "$EVERY" "$VARIABLE"`
  we exclude ShellCheck warnings related to [SC2086](https://github.com/koalaman/shellcheck/wiki/SC2086)
  and apply [the alternative](https://github.com/koalaman/shellcheck/wiki/SC2086#exceptions):
    * Disable globbing by using `set -f`, so that `PASSWORD=te?t*`
      would not expand to `test1.sh test2.py` from the current dir
        * This doesn't affect valuable `[[ $HAYSTACK == *NEEDLE* ]]`
        * Globbing can be temporary enabled with `set +f` when needed
          and then disabled again
    * Disable word splitting by space,
      but keep tab and newline in `IFS` (Internal Field Separator list),
      as we use them in places like:
        * `while read -r NAME VALUE` from `aws --output text` which is tab-separated
        * `for SECRET in $SECRETS` which is a newline-separated list
          that is way simpler to use than `"${ARRAYS[@]}"`
* We avoid using [shfmt](https://github.com/mvdan/sh) formatter
  (unlike python's [black](https://github.com/psf/black)) because:
    * `shfmt` is not easily installable - additional issue for CI/CD
    * It has [non-configurable](https://github.com/mvdan/sh/issues/248#issuecomment-396675460)
      decision to make the code less readable by adding `;`-s in few cases:
      ```bash
      # `if` as designed by bash authors:
      if $CONDITION
      then $ACTION
      fi

      # `if` as formatted by shfmt:
      if $CONDITION; then
      $ACTION
      fi
      ```
* We avoid using [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
  because it is focused on making the style compatible with other languages at Google,
  even when it breaks natural bash style, just like `shfmt` does above
    * However, we adopt some good ideas like separating lib names with `::`
      to make it clear which lib the function belongs to
* To avoid import loops, we import `lib`-s in `bin` entrypoints only
