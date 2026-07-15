# lesson-7 — Kubernetes (EKS), ECR та Helm-чарт для Django

## Структура проєкту

```
lesson-7/
│
├── main.tf                  # Головний файл для підключення модулів
├── backend.tf                # Налаштування бекенду для стейтів (S3 + DynamoDB)
├── versions.tf               # Провайдери (aws, tls) та їхні версії
├── outputs.tf                # Загальні виводи ресурсів
│
├── modules/
│   ├── s3-backend/           # S3-бакет + DynamoDB для стейтів
│   ├── vpc/                  # VPC, підмережі, IGW/NAT, теги для EKS/ELB
│   ├── ecr/                  # ECR-репозиторій для образу Django
│   └── eks/                  # EKS-кластер, managed node group, IAM, addons
│
└── charts/
    └── django-app/            # Helm-чарт застосунку
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            ├── configmap.yaml   # несекретні env
            ├── secret.yaml      # секретні env (SECRET_KEY, POSTGRES_PASSWORD)
            └── hpa.yaml
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

- ECR-репозиторій `lesson-7-django` для Docker-образу Django;
- EKS-кластер `lesson-7-eks` (control plane у публічних+приватних підмережах,
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
aws eks update-kubeconfig --region us-west-2 --name lesson-7-eks
kubectl get nodes
```

## 3. Збірка та завантаження образу Django в ECR

Образ збирається з каталогу `lesson-4` (де лежить Dockerfile застосунку):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=us-west-2
REPO_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region $REGION \
  | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

docker build -t django-app:latest ../lesson-4
docker tag django-app:latest $REPO_URL:latest
docker push $REPO_URL:latest
```

## 4. Розгортання Helm-чарта

Значення `image.repository` беремо з Terraform-виводу `ecr_repository_url`,
змінні середовища у `values.yaml` — це перенесені значення з `lesson-4/.env`.
Несекретні змінні (`env`) рендеряться в `ConfigMap`, а секретні (`secrets`:
`DJANGO_SECRET_KEY`, `POSTGRES_PASSWORD`) — в об'єкт `Secret`. Обидва
підключаються до контейнера через `envFrom` (`configMapRef` + `secretRef`).

```bash
cd ../lesson-7

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
