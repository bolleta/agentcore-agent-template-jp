resource "aws_iam_role" "bedrock_kb" {
    name = "${var.project_name}-bedrock-kb"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Effect    = "Allow"
            Principal = { Service = "bedrock.amazonaws.com" }
            Action    = "sts:AssumeRole"
        }]
    })
}

resource "aws_iam_role_policy" "bedrock_kb" {
    name = "bedrock-kb-policy"
    role = aws_iam_role.bedrock_kb.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect   = "Allow"
                Action   = ["s3:GetObject", "s3:ListBucket"]
                Resource = [
                    aws_s3_bucket.kb_source.arn,
                    "${aws_s3_bucket.kb_source.arn}/*",
                ]
            },
            {
                Effect   = "Allow"
                Action   = ["bedrock:InvokeModel"]
                Resource = "arn:aws:bedrock:${var.region}::foundation-model/cohere.embed-multilingual-v3"
            },
            {
                Effect = "Allow"
                Action = [
                    "s3vectors:*"
                ]
                Resource = "*"
            },
            {
                Effect = "Allow"
                Action = [
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents",
                ]
                Resource = aws_cloudwatch_log_group.kb_logs.arn
            },
        ]
    })
}

resource "aws_bedrockagent_knowledge_base" "agent" {
    name     = "${var.project_name}-kb"
    role_arn = aws_iam_role.bedrock_kb.arn

    knowledge_base_configuration {
        type = "VECTOR"
        vector_knowledge_base_configuration {
            embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/cohere.embed-multilingual-v3"
        }
    }

    storage_configuration {
        type = "S3_VECTORS"
        s3_vectors_configuration {
            index_arn = aws_s3vectors_index.kb_vectors.index_arn
        }
    }

    depends_on = [aws_iam_role_policy.bedrock_kb]
}

resource "aws_bedrockagent_data_source" "from_s3" {
    knowledge_base_id = aws_bedrockagent_knowledge_base.agent.id
    name              = "${var.project_name}-kb-s3"

    data_source_configuration {
        type = "S3"
        s3_configuration {
            bucket_arn = aws_s3_bucket.kb_source.arn
        }
    }

    vector_ingestion_configuration {
        chunking_configuration {
            # FIXED_SIZE: 均一なチャンク。短い FAQ や箇条書きドキュメントに向く。
            # 日本語は英語より文字密度が高いため max_tokens を小さめに設定。
            #
            # 長文ドキュメント（技術仕様書・マニュアルなど）では HIERARCHICAL の方が
            # 検索精度が上がることがある。切り替え例:
            #
            #   chunking_strategy = "HIERARCHICAL"
            #   hierarchical_chunking_configuration {
            #     level_configuration { max_tokens = 1500 }  # 親チャンク
            #     level_configuration { max_tokens = 150  }  # 子チャンク（検索対象）
            #     overlap_tokens = 30
            #   }
            chunking_strategy = "FIXED_SIZE"
            fixed_size_chunking_configuration {
                max_tokens         = 150
                overlap_percentage = 20
            }
        }
    }
}

# --- Trigger ingestion for uploaded docs 
resource "null_resource" "kb_sync" {
    triggers = {
        # Re-run whenever any document changes or the data source is recreated
        data_source_id    = aws_bedrockagent_data_source.from_s3.id
        knowledge_base_id = aws_bedrockagent_knowledge_base.agent.id
        docs_hash         = local.kb_source_docs_hash
    }

    provisioner "local-exec" {
        command = <<-EOT
            aws bedrock-agent start-ingestion-job \
                --knowledge-base-id ${aws_bedrockagent_knowledge_base.agent.id} \
                --data-source-id ${aws_bedrockagent_data_source.from_s3.data_source_id} 
        EOT
    }

    depends_on = [aws_s3_object.kb_docs, aws_bedrockagent_knowledge_base.agent]
}


resource "local_file" "kb_id" {
    content  = aws_bedrockagent_knowledge_base.agent.id
    filename = "${path.root}/../tmp/knowledge_base_id.txt"
}

output "kb_input_bucket_name" {
    value = aws_s3_bucket.kb_source.bucket
}

output "kb_id" {
    value = aws_bedrockagent_knowledge_base.agent.id
}
