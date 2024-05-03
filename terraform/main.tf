resource "aws_dynamodb_table" "demo_table" {

  name           = "kinesis_teste_table"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "pk"
  range_key      = "sk"


  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }


  global_secondary_index {
    name               = "Gsi"
    hash_key           = "sk"
    range_key          = "pk"
    write_capacity     = 5
    read_capacity      = 5
    projection_type    = "ALL"
  }

  tags = {
    Name        = "Dynamo-DB-Table"
    Environment = "Dev"
  }

  stream_enabled = true
  stream_view_type = "NEW_AND_OLD_IMAGES"
}



resource "aws_s3_bucket" "demo_bucket" {
  bucket = "kinesis-data-demo-1"

}


# Resource para a stream do Amazon Kinesis
resource "aws_kinesis_stream" "demo_stream" {
  name             = "demo-stream-test-7"
  retention_period = 24

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

# Resource para o delivery stream do Amazon Kinesis Firehose
resource "aws_kinesis_firehose_delivery_stream" "demo_delivery_stream" {
  name        = "demo-stream-delivery"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.demo_bucket.arn

    buffer_size = 5
    buffer_interval = 60
  }

  kinesis_source_configuration {
    kinesis_stream_arn  = aws_kinesis_stream.demo_stream.arn
    role_arn            = aws_iam_role.firehose.arn
  }

}

resource "aws_iam_role" "firehose" {
  name = "DemoFirehoseAssumeRole1"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "kinesis_firehose" {

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
        ],
        "Resource": "${aws_kinesis_stream.demo_stream.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "firehose_s3" {
  policy      = <<-EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Sid": "",
        "Effect": "Allow",
        "Action": [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
        ],
        "Resource": [
            "${aws_s3_bucket.demo_bucket.arn}",
            "${aws_s3_bucket.demo_bucket.arn}/*"
        ]
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "firehose_s3" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose_s3.arn
}

resource "aws_iam_policy" "put_record" {
  policy      = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "firehose:PutRecord",
                "firehose:PutRecordBatch"
            ],
            "Resource": [
                "${aws_kinesis_firehose_delivery_stream.demo_delivery_stream.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "put_record" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.put_record.arn
}

resource "aws_iam_role_policy_attachment" "kinesis_firehose" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.kinesis_firehose.arn
}



resource "aws_dynamodb_kinesis_streaming_destination" "destination-stream" {
  stream_arn = aws_kinesis_stream.demo_stream.arn
  table_name = aws_dynamodb_table.demo_table.name
  depends_on = [ aws_dynamodb_table.demo_table, aws_kinesis_stream.demo_stream ]
}