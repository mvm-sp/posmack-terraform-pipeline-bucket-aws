# posmack-terraform-pipeline-bucket-aws
Repository to test a pipeline execution on AWS

Nesse repositório você encontrará conteúdo construído a partir deste roteiro básico:

1. Criar um script Terraform bem estruturado para provisionar uma bucket S3
No Terraform, você começaria definindo o provider AWS e a configuração para criar um bucket S3 com versionamento habilitado. Um exemplo básico pode ser o seguinte:

````hcl

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "meu-bucket-s3"
  acl    = "private"

  versioning {
    enabled = true
  }
}

````
Esse código cria um bucket no S3 com a configuração de versionamento habilitada, garantindo que todas as versões dos objetos sejam armazenadas.

2. Criar os arquivos workflow para provisionamento em múltiplos ambientes
Para provisionar em múltiplos ambientes, como desenvolvimento, teste e produção, é importante estruturar o Terraform com workspaces ou definir variáveis para cada ambiente. Um exemplo com variáveis:

```hcl
variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "meu-bucket-s3-${var.environment}"
  acl    = "private"

  versioning {
    enabled = true
  }
}
```
Dessa forma, o bucket será criado com um nome específico para cada ambiente (meu-bucket-s3-dev, meu-bucket-s3-prod).

3. Configurar o Identity Provider do GitHub na conta AWS
Para permitir que o GitHub Actions assuma uma Role na AWS, você precisa configurar um Identity Provider na AWS que confie no GitHub. Isso pode ser feito manualmente no console AWS ou via Terraform.

Aqui está um exemplo para configurar via Terraform:
```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["A031C46782E6E6C662C2C87C76DA9AA62CCABD8E"]  # Atualize com o fingerprint correto do GitHub
}
```
4. Configurar uma IAM Role com permissões mínimas (S3 e DynamoDB)
Aqui, criamos uma IAM Role que pode ser assumida pela GitHub Actions, com permissões mínimas de S3 e DynamoDB:

```hcl
resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"
  
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "${aws_iam_openid_connect_provider.github.arn}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringLike": {
            "token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:*"
          }
        }
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "github_actions_policy" {
  name = "GitHubActionsPolicy"
  
  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:*",
          "dynamodb:*"
        ],
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}
```

5. Criar um Bucket S3 com versionamento habilitado
Já foi mostrado na primeira etapa como criar o bucket com versionamento habilitado. Este código pode ser reutilizado em sua infraestrutura.

6. Criar uma tabela no DynamoDB (PartitionKey com o nome "LockID")
A criação de uma tabela DynamoDB com uma chave de partição LockID pode ser feita com o seguinte código:

```hcl
resource "aws_dynamodb_table" "my_table" {
  name           = "my-lock-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```
Essa tabela pode ser usada, por exemplo, como tabela de bloqueio para o Terraform ou em outras aplicações que precisem de controle de concorrência.

7. Configurar o workflow para utilizar suas credenciais via AssumeRole
No GitHub Actions, você pode configurar um workflow que assume a Role que você configurou na AWS. Um exemplo básico de workflow no GitHub Actions:

```yaml

name: Deploy to AWS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    permissions:
      id-token: write
      contents: read

    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActionsRole
        aws-region: us-east-1

    - name: Deploy with Terraform
      run: |
        terraform init
        terraform apply -auto-approve
```
Aqui, o workflow assume a Role GitHubActionsRole e executa comandos Terraform para deployar a infraestrutura.

Conclusão
Esse projeto abrange desde a criação de buckets S3 e tabelas DynamoDB com Terraform até a configuração de roles e workflows para integrar a automação via GitHub Actions. Você pode estender o projeto para incluir testes, diferentes ambientes, e práticas de segurança adicionais.
