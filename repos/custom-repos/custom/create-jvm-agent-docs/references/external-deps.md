# External Dependencies Reference

Load this file when identifying external systems and their entity identifiers.

## How to Find Dependencies

### SQL Databases (PostgreSQL, MySQL, MSSQL, Oracle)

**Entity format:** `database.schema.table`

**Where to look:**
- JPA/Hibernate: `@Entity`, `@Table(name = "...")` annotations
- Slick: table definitions in `*Table` classes
- Flyway/Liquibase migrations: `db/migration/`, `changelog/`
- JOOQ: generated code in `jooq/` or `generated/`
- Raw SQL: `*.sql` files, `@Query` annotations
- Config: JDBC URL contains database name (`jdbc:postgresql://host/dbname`)
- Spring: `spring.datasource.url`, `spring.jpa.properties.*`
- HOCON: `slick.db.url`, `db.default.url`

**Record:** Each table the service reads from or writes to.

---

### MongoDB

**Entity format:** `database.collection`

**Where to look:**
- Spring Data: `@Document(collection = "...")` annotations
- Mongo Scala Driver: `database.getCollection("...")` calls
- Morphia: `@Entity("collection_name")` annotations
- Config: database name in connection URI or config property
- DAO/Repository classes: collection references

**Record:** Each collection accessed, noting read-only vs read-write.

---

### Kafka

**Entity format:** `topic` (+ `consumer_group`)

**Where to look:**
- Spring: `@KafkaListener(topics = "...")`, `@SendTo("...")`, `KafkaTemplate` usage
- Akka/Alpakka: topic names in config under `topicNames` or consumer props
- Config: `bootstrap.servers`, `group.id`, topic names as config values
- Producer code: `.send(new ProducerRecord("topic", ...))` or equivalent
- Consumer group: `group.id` in consumer config or `@KafkaListener(groupId = "...")`

**Record:** All topics consumed AND produced, with consumer group IDs.

---

### RabbitMQ

**Entity format:** `exchange` / `queue` / `routing_key`

**Where to look:**
- Spring AMQP: `@RabbitListener(queues = "...")`, `@Exchange`, `@QueueBinding`
- Config: `spring.rabbitmq.*`, exchange/queue declarations in `@Configuration` classes
- Channel setup: `channel.exchangeDeclare(...)`, `channel.queueBind(...)`

**Record:** Exchanges, queues, and binding routing keys.

---

### REST APIs (consumed)

**Entity format:** `METHOD /endpoint`

**Where to look:**
- HTTP clients: `WebClient`, `RestTemplate`, `HttpClient`, `Akka HTTP`, `sttp`, `Retrofit` usage
- Feign: `@FeignClient` interfaces with `@GetMapping`/`@PostMapping`
- Config: base URLs as env vars or config properties
- OpenAPI/Swagger specs: `*.yaml`, `*.json` API definitions

**Record:** Base URL (per environment) + specific endpoints called.

---

### gRPC

**Entity format:** `package.Service/Method`

**Where to look:**
- `.proto` files: `service` and `rpc` definitions
- Generated stubs: `*Grpc.java`, `*ServiceGrpc`
- Client config: target addresses, channel builders

**Record:** Each service/method invoked or served.

---

### Redis

**Entity format:** `key_pattern` or `channel` (pub/sub)

**Where to look:**
- Spring: `@Cacheable`, `RedisTemplate`, `StringRedisTemplate` usage
- Lettuce/Jedis: `get()`, `set()`, `publish()` calls
- Config: `spring.redis.*`, `redis.host`, connection pool settings
- Cache annotations: `@Cacheable(value = "cacheName")`

**Record:** Key patterns, cache names, pub/sub channels.

---

### Elasticsearch / OpenSearch

**Entity format:** `index_name`

**Where to look:**
- Spring Data Elasticsearch: `@Document(indexName = "...")`
- REST client: index names in queries, `CreateIndexRequest`
- Config: cluster hosts, index settings

**Record:** Each index read from or written to.

---

### Object Storage (S3 / GCS / Azure Blob)

**Entity format:** `bucket/prefix`

**Where to look:**
- AWS SDK: `AmazonS3`, `S3Client`, bucket names in config
- GCS: `Storage` client, bucket references
- Config: bucket names as env vars, IAM role assumptions

**Record:** Buckets and key prefixes used.

---

### Google Pub/Sub / AWS SQS / SNS

**Entity format:** `topic` or `subscription` / `queue_url`

**Where to look:**
- Spring Cloud: `@ServiceActivator`, `MessageChannel` beans
- AWS SDK: queue URLs, topic ARNs
- Config: topic/subscription names

---

## Per-Environment Connection Details

Always extract connection details for each environment from:
- Helm values (`helm/values.*.yaml`)
- Docker Compose profiles
- Spring profiles (`application-{profile}.yml`)
- CI/CD env var definitions
- Terraform/infrastructure-as-code

Record as a table:

```markdown
| Env | Host/URL | Notes |
|-----|----------|-------|
| dev | ... | ... |
| staging | ... | ... |
| prod | ... | ... |
```

## Downstream Consumers

Also document what **reads from** this service's output:
- Other services consuming your Kafka topics
- Services querying your database
- Elasticsearch indices populated by your data
- APIs that cache or proxy your responses
