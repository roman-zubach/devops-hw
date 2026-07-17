# lesson-8-9 — CI/CD: Jenkins + Kaniko + ECR + Argo CD на EKS

Повний CI/CD-конвеєр: Jenkins збирає Docker-образ Django через Kaniko, пушить
його в ECR, оновлює тег у `values.yaml` та пушить у Git, після чого Argo CD
автоматично синхронізує застосунок у кластері. Уся інфраструктура (кластер,
Jenkins, Argo CD) піднімається через Terraform + Helm.

## Структура проєкту

```
lesson-8-9/
│
├── main.tf                   # Підключення модулів (s3, vpc, ecr, eks, jenkins, argo_cd)
├── backend.tf                # Бекенд для стейтів (S3 + DynamoDB)
├── versions.tf               # Провайдери (aws, tls, kubernetes, helm)
├── providers.tf              # Конфіг kubernetes+helm провайдерів з EKS
├── outputs.tf                # Загальні виводи
│
├── Dockerfile                # Образ Django-застосунку
├── manage.py, config/        # Мінімальний Django-застосунок
├── Jenkinsfile               # Pipeline: Kaniko build → ECR → bump tag → git push
│
├── modules/
│   ├── s3-backend/           # S3-бакет + DynamoDB для стейтів
│   ├── vpc/                  # VPC, підмережі, IGW/NAT, теги для EKS/ELB
│   ├── ecr/                  # ECR-репозиторій для образу Django
│   ├── eks/                  # EKS-кластер, node group, IAM, addons
│   ├── rds/                  # Універсальний RDS/Aurora (use_aurora) + SG/subnet/parameter group
│   ├── jenkins/              # Helm-реліз Jenkins + IRSA для Kaniko-агента
│   │   ├── jenkins.tf        # namespace, IAM (IRSA), SA, helm_release
│   │   ├── values.yaml       # JCasC seed-джоба, плагіни, kubernetes-агент
│   │   ├── providers.tf, variables.tf, outputs.tf
│   └── argo_cd/              # Helm-реліз Argo CD + app-of-apps
│       ├── argo_cd.tf        # namespace, helm_release argo-cd + apps
│       ├── values.yaml       # конфіг Argo CD
│       ├── charts/           # app-of-apps чарт
│       │   ├── Chart.yaml
│       │   ├── values.yaml
│       │   └── templates/
│       │       ├── application.yaml   # Argo CD Application (auto-sync)
│       │       └── repository.yaml    # Repository secret
│       └── providers.tf, variables.tf, outputs.tf
│
└── charts/
    └── django-app/           # Helm-чарт застосунку (deployment/service/hpa/…)
```

## 1. Бутстрап бекенду (якщо ще не зроблено)

Бекенд S3 сам по собі створюється через Terraform, тож перед першим `apply`
бакета й таблиці DynamoDB ще не існує (класичне «замкнене коло» бекенду):

1. Закоментуйте блок `backend "s3"` у `backend.tf`, щоб Terraform використав
   локальний стейт.
2. Створіть лише бекенд-ресурси:
   ```bash
   terraform init
   terraform apply -target=module.s3_backend
   ```
3. Розкоментуйте блок `backend "s3"`.
4. Мігруйте стейт у бакет: `terraform init -migrate-state`.

## 2. Створення VPC, ECR та EKS-кластера

```bash
terraform init
terraform plan
terraform apply
```

Це створює (у мережі з попереднього ДЗ):

- ECR-репозиторій `lesson-8-9-django` для Docker-образу Django;
- EKS-кластер `lesson-8-9-eks` (control plane у публічних+приватних підмережах,
  managed node group із 2 worker-нод у приватних підмережах, addons
  `vpc-cni`, `kube-proxy`, `coredns`, `metrics-server` — останній потрібен
  для роботи HPA);
- OIDC-провайдер кластера (для IRSA, якщо знадобиться в майбутньому);
- теги `kubernetes.io/cluster/<name>` та `kubernetes.io/role/elb` /
  `internal-elb` на підмережах — потрібні, щоб Service типу `LoadBalancer`
  міг автоматично створити Classic ELB у правильних підмережах.

> Якщо у вашому регіоні/акаунті EKS-addon `metrics-server` недоступний,
> заберіть ресурс `aws_eks_addon.metrics_server` з `modules/eks/eks.tf` і
> встановіть metrics-server окремо: `helm install metrics-server
> metrics-server/metrics-server -n kube-system`. Без metrics-server HPA не
> зможе отримувати метрики CPU.

Після `apply` підключіть `kubectl` до кластера (команда також є в
`terraform output eks_configure_kubectl`):

```bash
aws eks update-kubeconfig --region us-west-2 --name lesson-8-9-eks
kubectl get nodes
```

## 3. Збірка та завантаження образу Django в ECR

Образ збирається з каталогу `lesson-8-9` (де лежить Dockerfile застосунку):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-west-2
REPO_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

docker build -t django-app:latest ../lesson-8-9
docker tag django-app:latest $REPO_URL:latest
docker push $REPO_URL:latest
```

## 4. Розгортання Helm-чарта

Значення `image.repository` беремо з Terraform-виводу `ecr_repository_url`,
змінні середовища у `values.yaml` — це перенесені значення з `lesson-8-9/.env`.
Несекретні змінні (`env`) рендеряться в `ConfigMap`, а секретні (`secrets`:
`DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD`) — в об'єкт `Secret`. Обидва
підключаються до контейнера через `envFrom` (`configMapRef` + `secretRef`).

```bash
cd ../lesson-8-9

REPO_URL=$(terraform output -raw ecr_repository_url)

helm upgrade --install django-app ./charts/django-app \
  --set image.repository=$REPO_URL \
  --set image.tag=latest
```

Перевірка:

```bash
kubectl get pods                         # 2+ у статусі Running
kubectl get configmap
kubectl get secret
kubectl get hpa                          # у колонці TARGETS має бути %, не <unknown>
kubectl get svc django-app-django-app   # EXTERNAL-IP — адреса Classic ELB
```

Deployment підключає ConfigMap через `envFrom`, Service має тип
`LoadBalancer` для зовнішнього доступу, а HPA масштабує поди від 2 до 6 при
завантаженні CPU понад 70%.

## Команди Terraform

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Модулі

### s3-backend

Створює S3-бакет для зберігання Terraform-стейтів (з увімкненим
версіюванням) та таблицю DynamoDB для блокування стейтів під час
одночасних `apply`.

### vpc

Створює VPC із трьома публічними та трьома приватними підмережами.
Публічні підмережі мають маршрут до Internet Gateway. Приватні підмережі
виходять в інтернет через спільний NAT Gateway. Якщо передано
`cluster_name`, підмережі додатково позначаються тегами
`kubernetes.io/cluster/<name>` та `kubernetes.io/role/elb` /
`internal-elb`, необхідними для EKS та автоматичного створення Load
Balancer'ів.

### ecr

Створює ECR-репозиторій з автоматичним скануванням образів при пуші та
політикою доступу, яка дозволяє поточному AWS-акаунту пушити й тягнути
образи.

### eks

Створює EKS-кластер (control plane) та managed node group у приватних
підмережах, необхідні IAM-ролі та політики для кластера і нод, OIDC-провайдер
для IRSA, а також addons `vpc-cni`, `kube-proxy`, `coredns` і
`metrics-server`.

### jenkins

Встановлює Jenkins через офіційний Helm-чарт `jenkins/jenkins` у namespace
`jenkins`. Додатково створює:

- **IRSA-роль для Kaniko-агента** — IAM-роль `<cluster>-jenkins-agent`, довірена
  до service account `jenkins-agent` через OIDC-провайдер кластера. Політика
  дозволяє `ecr:GetAuthorizationToken` та пуш образів у ECR-репозиторій. Завдяки
  цьому Kaniko автентифікується в ECR **без статичних ключів**.
- **ServiceAccount `jenkins-agent`** з анотацією `eks.amazonaws.com/role-arn`.
- **JCasC seed-джобу** — `values.yaml` через Configuration as Code створює
  pipeline-джобу `django-app-ci`, що тягне `Jenkinsfile` з Git (гілка `main`).

Плагіни: `kubernetes` (агенти-поди), `git`, `workflow-aggregator`,
`configuration-as-code`, `job-dsl`.

### argo_cd

Встановлює Argo CD через Helm-чарт `argo/argo-cd` у namespace `argocd`, а потім
локальний **app-of-apps** чарт (`modules/argo_cd/charts`), який створює:

- `Application` `django-app` з `syncPolicy.automated` (prune + selfHeal) —
  Argo CD безперервно звіряє стан кластера з Git і синхронізує зміни;
- `Repository` secret, що реєструє Git-репозиторій джерелом.

Application вказує на `lesson-8-9/charts/django-app` у Git. Коли Jenkins оновлює
`image.tag` у `values.yaml` та пушить у `main`, Argo CD підхоплює коміт і
розгортає новий образ.

### rds

Універсальний модуль, який на основі змінної `use_aurora` підіймає **Aurora
Cluster** (`aws_rds_cluster` + `aws_rds_cluster_instance`, writer/reader) або
одну звичайну **RDS-інстанс** (`aws_db_instance` з опційним Multi-AZ). В обох
випадках автоматично створює `aws_db_subnet_group`, `aws_security_group` (доступ
до порту БД з дозволених CIDR/SG) та Parameter Group із базовими параметрами
(`max_connections`, `log_statement`, `work_mem`) — `aws_db_parameter_group` для
звичайної RDS або `aws_rds_cluster_parameter_group` для Aurora. Рушій, версія,
клас інстансу та відмовостійкість задаються через змінні.

| `use_aurora` | Що створюється |
|--------------|----------------|
| `true`  | `aws_rds_cluster` + `aws_rds_cluster_instance` (перший — writer, решта — reader) |
| `false` | одна `aws_db_instance` (з опційним Multi-AZ) |

#### Приклад використання

Звичайна PostgreSQL RDS:

```hcl
module "rds" {
  source = "./modules/rds"

  name       = "lesson-8-9"
  use_aurora = false

  engine         = "postgres"
  engine_version = "16.4"
  instance_class = "db.t3.micro"
  multi_az       = false

  db_name  = "appdb"
  username = "dbadmin"
  password = var.db_password
  port     = 5432

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  allowed_cidr_blocks        = ["10.0.0.0/16"]
  allowed_security_group_ids = [module.eks.cluster_security_group_id]

  db_parameter_group_family = "postgres16"

  tags = { Environment = "lesson-8-9", Project = "django-app" }
}
```

Aurora PostgreSQL Cluster — той самий блок із:

```hcl
  use_aurora            = true
  engine                = "aurora-postgresql"
  aurora_instance_count = 2 # 1 writer + 1 reader

  aurora_cluster_parameter_group_family = "aurora-postgresql16"
```

#### Змінні

| Змінна | Тип | Дефолт | Опис |
|--------|-----|--------|------|
| `name` | `string` | — | Базовий префікс для імен ресурсів |
| `use_aurora` | `bool` | `false` | `true` → Aurora Cluster, `false` → звичайна RDS |
| `engine` | `string` | `"postgres"` | `postgres`/`mysql`/`mariadb` або `aurora-postgresql`/`aurora-mysql` |
| `engine_version` | `string` | `"16.4"` | Версія рушія |
| `instance_class` | `string` | `"db.t3.micro"` | Клас інстансу БД |
| `multi_az` | `bool` | `false` | Multi-AZ для звичайної RDS |
| `allocated_storage` | `number` | `20` | Розмір сховища (ГБ), тільки для звичайної RDS |
| `storage_type` | `string` | `"gp3"` | Тип сховища (`gp2`/`gp3`/`io1`) |
| `aurora_instance_count` | `number` | `1` | Кількість інстансів у Aurora-кластері |
| `db_name` | `string` | `"appdb"` | Ім'я початкової БД |
| `username` | `string` | `"dbadmin"` | Master-користувач |
| `password` | `string` (sensitive) | — | Пароль master-користувача |
| `port` | `number` | `5432` | Порт БД (5432 postgres / 3306 mysql) |
| `vpc_id` | `string` | — | ID VPC |
| `subnet_ids` | `list(string)` | — | Підмережі для DB Subnet Group |
| `allowed_cidr_blocks` | `list(string)` | `[]` | CIDR-блоки з доступом до порту БД |
| `allowed_security_group_ids` | `list(string)` | `[]` | SG з доступом до порту БД |
| `publicly_accessible` | `bool` | `false` | Публічна адреса БД |
| `db_parameter_group_family` | `string` | `"postgres16"` | Family для звичайної RDS |
| `aurora_cluster_parameter_group_family` | `string` | `"aurora-postgresql16"` | Family для Aurora |
| `parameters` | `list(object)` | `max_connections`, `log_statement`, `work_mem` | Параметри Parameter Group |
| `backup_retention_period` | `number` | `7` | Днів зберігання бекапів |
| `skip_final_snapshot` | `bool` | `true` | Пропустити фінальний snapshot |
| `storage_encrypted` | `bool` | `true` | Шифрування сховища |
| `tags` | `map(string)` | `{}` | Теги для всіх ресурсів |

Виводи: `endpoint`, `reader_endpoint` (тільки Aurora), `port`, `db_name`,
`username`, `security_group_id`, `db_subnet_group_name`, `parameter_group_name`,
`is_aurora`.

#### Як змінити тип БД / engine / клас інстансу

- **Aurora ↔ звичайна RDS** — змініть `use_aurora` (`true`/`false`), решта логіки
  перемикається автоматично.
- **MySQL замість PostgreSQL** — `engine = "mysql"` (або `"aurora-mysql"`),
  `engine_version = "8.0"`, `port = 3306`, `db_parameter_group_family = "mysql8.0"`
  (для Aurora — `aurora_cluster_parameter_group_family = "aurora-mysql8.0"`).
- **Версія** — оновіть `engine_version` і відповідний `*_family` (family прив'язаний
  до major-версії, напр. `postgres16` / `postgres15`).
- **Клас інстансу** — `instance_class` (напр. `db.t3.large`, `db.r6g.large`).
- **Відмовостійкість** — для звичайної RDS `multi_az = true`; для Aurora збільшіть
  `aurora_instance_count`.
- **Параметри БД** — передайте власний список `parameters`; для статичних параметрів
  (напр. `max_connections`) вкажіть `apply_method = "pending-reboot"`.

## CI/CD-конвеєр (Jenkins → ECR → Argo CD)

### Передумови в Jenkins

Після `terraform apply` у Jenkins потрібно додати обліковий запис для пушу в Git:

1. Відкрити UI (`terraform output jenkins_port_forward`), увійти
   (`admin` / `admin123` за замовчуванням — змініть у проді).
2. **Manage Jenkins → Credentials** → додати *Username with password* з ID
   `github-credentials` (username + GitHub Personal Access Token з правами
   `repo`). Саме на цей ID посилається `Jenkinsfile`.

### Що робить `Jenkinsfile`

Запускається на Kubernetes-поді з контейнерами `kaniko`, `aws`, `git` під
service account `jenkins-agent`:

1. **Resolve ECR & tag** — визначає `account_id`, формує тег
   `<BUILD_NUMBER>-<git-sha>`.
2. **Build & push (Kaniko)** — збирає образ із `lesson-8-9/Dockerfile` і пушить
   у ECR (`:<tag>` та `:latest`). Автентифікація в ECR — через IRSA.
3. **Update Helm values & push** — клонує репозиторій, оновлює `image.tag` у
   `lesson-8-9/charts/django-app/values.yaml`, комітить і пушить у `main`.

Далі **Argo CD** автоматично синхронізує застосунок із новим тегом.

### Доступ до UI

```bash
# Jenkins
kubectl -n jenkins port-forward svc/jenkins 8080:8080      # http://localhost:8080

# Argo CD
kubectl -n argocd port-forward svc/argocd-server 8081:443  # https://localhost:8081
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d               # пароль admin
```

Відповідні команди також є у виводах: `jenkins_port_forward`,
`argocd_port_forward`, `argocd_admin_password_command`.

> **Порядок apply.** Kubernetes/Helm-провайдери налаштовуються з даних
> EKS-кластера, тож модулі `jenkins` і `argo_cd` створюються лише після `eks`
> (задано через `depends_on`). При першому розгортанні з нуля зручно спершу
> підняти кластер (`terraform apply -target=module.eks`), а потім повний
> `terraform apply`.
