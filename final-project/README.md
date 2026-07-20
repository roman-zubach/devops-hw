# Final Project — DevOps-інфраструктура на AWS (Terraform)

Повний DevOps-стек на AWS, зібраний одним `terraform apply`: мережа, EKS-кластер,
контейнерний реєстр, база даних, CI/CD (Jenkins + Argo CD) і моніторинг
(Prometheus + Grafana).

Django-застосунок збирається Jenkins'ом через Kaniko, пушиться в ECR, після чого
Argo CD автоматично синхронізує його в кластер. HPA масштабує застосунок за CPU,
а Prometheus/Grafana збирають і візуалізують метрики кластера.

## Архітектура

```
                         ┌──────────────────────── AWS ────────────────────────┐
                         │                                                      │
   GitHub ──webhook──►   │  VPC (10.0.0.0/16)                                   │
   (Jenkinsfile,         │   ├── public subnets  → IGW  → ELB (Django Service)  │
    Helm charts)         │   └── private subnets → NAT                          │
        ▲                │        └── EKS node group (t3.medium ×2–4)           │
        │ git push       │             ├── ns jenkins     (Jenkins + Kaniko)    │
        │ (bump tag)     │             ├── ns argocd      (Argo CD app-of-apps) │
        │                │             ├── ns monitoring  (Prometheus+Grafana)  │
   Jenkins ──build──► ECR │             └── ns default     (Django + HPA)        │
                         │        RDS/Aurora (private subnets, SG-обмежений)     │
                         │  S3 + DynamoDB — backend для Terraform-стейту         │
                         └──────────────────────────────────────────────────────┘
```

## Компоненти (відповідність вимогам)

| Вимога | Реалізація |
|--------|------------|
| Kubernetes-кластер (EKS) з CI/CD | `modules/eks` + Jenkins/Argo CD |
| Jenkins | `modules/jenkins` (Helm, IRSA, Kaniko, JCasC seed job) |
| Argo CD | `modules/argo_cd` (Helm, app-of-apps) |
| База даних (RDS або Aurora) | `modules/rds` (перемикач `use_aurora`) |
| Контейнерний реєстр (ECR) | `modules/ecr` |
| Моніторинг (Prometheus + Grafana) | `modules/monitoring` (kube-prometheus-stack) |
| Автомасштабування | HPA (`charts/django-app`) + EKS node group scaling |

## Структура

```
final-project/
├── main.tf                    # Підключення всіх модулів
├── backend.tf                 # Бекенд стейту (S3 + DynamoDB)
├── providers.tf               # kubernetes+helm провайдери з даних EKS
├── versions.tf                # Провайдери (aws, tls, kubernetes, helm)
├── variables.tf               # db_password, grafana_admin_password
├── outputs.tf                 # Загальні виводи (URL, port-forward команди)
│
├── Dockerfile, manage.py, config/   # Django-застосунок
├── Jenkinsfile                # Pipeline: Kaniko build → ECR → bump tag → git push
│
├── modules/
│   ├── s3-backend/            # S3-бакет + DynamoDB для стейту
│   ├── vpc/                   # VPC, public/private підмережі, IGW/NAT, теги EKS/ELB
│   ├── ecr/                   # ECR-репозиторій
│   ├── eks/                   # EKS-кластер, node group, IAM, OIDC, addons
│   │   ├── eks.tf
│   │   └── aws_ebs_csi_driver.tf   # EBS CSI Driver (IRSA + addon) для PVC
│   ├── rds/                   # Універсальний RDS/Aurora
│   ├── jenkins/              # Helm-реліз Jenkins + IRSA для Kaniko
│   ├── argo_cd/              # Helm-реліз Argo CD + app-of-apps
│   └── monitoring/           # kube-prometheus-stack (Prometheus + Grafana)
│       ├── monitoring.tf     # namespace, StorageClass gp3, helm_release
│       ├── values.yaml       # конфіг Grafana/Prometheus
│       ├── variables.tf, outputs.tf, providers.tf
│
└── charts/
    └── django-app/           # Helm-чарт застосунку (deployment/service/configmap/hpa)
```

## Передумови

- AWS CLI з налаштованими креденшелами, `kubectl`, `helm`, `terraform >= 1.5`.
- Єдиний секрет, який задає користувач, — master-пароль БД (передається через
  змінну середовища, у git не зберігається):
  ```bash
  export TF_VAR_db_password='<надійний-пароль>'
  ```
- Паролі Jenkins, Grafana та `DJANGO_SECRET_KEY` **генеруються автоматично**
  (`random_password`) і читаються з виводів:
  ```bash
  terraform output -raw jenkins_admin_password
  terraform output -raw grafana_admin_password
  ```

## 1. Бутстрап бекенду (перший запуск)

S3-бакет і DynamoDB для стейту створюються самим Terraform, тож на першому
`apply` їх ще немає («замкнене коло» бекенду):

1. Закоментуйте блок `backend "s3"` у `backend.tf`.
2. Створіть лише ресурси бекенду:
   ```bash
   terraform init
   terraform apply -target=module.s3_backend
   ```
3. Розкоментуйте блок `backend "s3"` і мігруйте стейт:
   ```bash
   terraform init -migrate-state
   ```

## 2. Розгортання інфраструктури

```bash
terraform init
terraform plan
terraform apply
```

> **Порядок apply.** Провайдери `kubernetes`/`helm` конфігуруються з даних
> EKS-кластера, тож при розгортанні з нуля зручно спершу підняти кластер, а
> потім усе інше:
> ```bash
> terraform apply -target=module.eks
> terraform apply
> ```

Підключіть `kubectl` (команда також у `terraform output eks_configure_kubectl`):

```bash
aws eks update-kubeconfig --region us-west-2 --name final-project-eks
kubectl get nodes
```

## 3. Перевірка стану компонентів

```bash
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
kubectl get hpa                 # автомасштабування Django (TARGETS має бути %, не <unknown>)
kubectl get storageclass        # gp3 (ebs.csi.aws.com)
kubectl get pvc -n monitoring   # томи Prometheus/Grafana у статусі Bound
```

## 4. Доступ до сервісів (port-forward)

```bash
# Jenkins  (логін admin, пароль: terraform output -raw jenkins_admin_password)
kubectl -n jenkins port-forward svc/jenkins 8080:8080          # http://localhost:8080

# Argo CD
kubectl -n argocd port-forward svc/argocd-server 8081:443      # https://localhost:8081
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d                   # пароль admin

# Grafana  (логін admin, пароль: terraform output -raw grafana_admin_password)
kubectl -n monitoring port-forward svc/grafana 3000:80         # http://localhost:3000

# Prometheus
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

Ці ж команди є у виводах: `jenkins_port_forward`, `argocd_port_forward`,
`grafana_port_forward`, `prometheus_port_forward`.

## CI/CD-конвеєр (Jenkins → ECR → Argo CD)

1. У Jenkins (**Manage Jenkins → Credentials**) додайте *Username with password*
   з ID `github-credentials` (username + GitHub PAT з правами `repo`) — на цей ID
   посилається `Jenkinsfile`.
2. Джоба `django-app-ci` (створюється через JCasC) запускається на Kubernetes-поді
   з контейнерами `kaniko`/`aws`/`git` під service account `jenkins-agent`:
   - **Build & push (Kaniko)** — збирає образ із `final-project/Dockerfile`, пушить
     у ECR (`:<build>-<sha>` та `:latest`). Автентифікація в ECR — через IRSA, без
     статичних ключів.
   - **Update Helm values & push** — оновлює `image.tag` у
     `final-project/charts/django-app/values.yaml`, комітить і пушить у `main`.
3. **Argo CD** (`Application` з `syncPolicy.automated` + prune + selfHeal) підхоплює
   коміт і розгортає новий образ у кластер.

## Застосунок і база даних

- Django працює на **gunicorn** (production WSGI), статика обслуговується
  **WhiteNoise** (`collectstatic` на етапі збірки образу). Dev-сервер
  `runserver` не використовується.
- База даних — **PostgreSQL на RDS**. `config/settings.py` вмикає
  `django.db.backends.postgresql`, якщо задано `POSTGRES_HOST` (у кластері —
  завжди), інакше падає на SQLite лише для локального запуску.
- **Секрети не зберігаються у git.** Конфіг подається через `envFrom`:
  - статичні несекретні змінні (`DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`,
    `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PORT`) — у ConfigMap чарта (`values.yaml`);
  - динамічне й секретне (`POSTGRES_HOST` — реальний endpoint RDS,
    `POSTGRES_PASSWORD` = `var.db_password`, `DJANGO_SECRET_KEY` — згенерований
    `random_password`) — у Secret `django-app-secrets`, який створює Terraform.

  Чарт лише посилається на Secret за іменем (`externalSecretName` у `values.yaml`),
  тож у репозиторії немає жодного пароля.

## Моніторинг та автомасштабування

- **Prometheus + Grafana** розгортаються чартом `kube-prometheus-stack` у namespace
  `monitoring` (разом із node-exporter та kube-state-metrics). Метрики зберігаються
  на EBS-томах через StorageClass `gp3` (провайдер `ebs.csi.aws.com`). У Grafana
  автоматично встановлюються кластерні дашборди Kubernetes — CPU/пам'ять нод і подів,
  стан ресурсів кластера.
- **HPA** (`charts/django-app/templates/hpa.yaml`) масштабує Django від 2 до 6
  реплік при CPU > 70%. Метрики для HPA дає addon `metrics-server`.
- **EKS node group** масштабується від 2 до 4 нод (`node_min_size`/`node_max_size`).

## Безпека

- **VPC-ізоляція** — worker-ноди та RDS у приватних підмережах; вихід в інтернет
  лише через NAT Gateway. Публічними лишаються тільки підмережі під ELB.
- **Security Groups** — доступ до порту БД дозволено виключно з CIDR VPC та з SG
  EKS-кластера (`allowed_security_group_ids`), а не з `0.0.0.0/0`.
- **IAM / IRSA** — окремі ролі з мінімальними правами: роль кластера, роль нод,
  IRSA-роль Kaniko-агента (лише пуш у конкретний ECR-репозиторій) та IRSA-роль
  контролера EBS CSI Driver. Kaniko та CSI-драйвер автентифікуються через OIDC
  без статичних ключів.
- **Керування секретами** — жоден пароль не хардкодиться: master-пароль БД
  задається через `TF_VAR_db_password`, а паролі Jenkins/Grafana і
  `DJANGO_SECRET_KEY` генеруються `random_password`. Прикладні секрети живуть
  у Kubernetes Secret (керованому Terraform), а не у git.
- **Шифрування** — сховище RDS шифрується (`storage_encrypted`), стейт у S3 —
  `encrypt = true`, сканування образів у ECR при пуші.

## Команди Terraform

```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Опис модулів

- **s3-backend** — S3-бакет (з версіюванням) + DynamoDB для блокування стейту.
- **vpc** — VPC з 3 публічними та 3 приватними підмережами, IGW, спільний NAT,
  теги `kubernetes.io/cluster/<name>` та `role/elb`/`internal-elb` для EKS/ELB.
- **ecr** — ECR-репозиторій зі скануванням образів і політикою доступу акаунта.
- **eks** — control plane + managed node group, IAM-ролі, OIDC-провайдер, addons
  `vpc-cni`/`kube-proxy`/`coredns`/`metrics-server`/`aws-ebs-csi-driver`.
- **rds** — універсальний модуль: `use_aurora = true` → Aurora Cluster
  (writer + reader), `false` → одна RDS-інстанс (з опційним Multi-AZ). Автоматично
  створює subnet group, security group і parameter group.
- **jenkins** — Helm-реліз Jenkins + IRSA-роль Kaniko-агента + JCasC seed-джоба.
- **argo_cd** — Helm-реліз Argo CD + локальний app-of-apps чарт (`Application` +
  `Repository`).
- **monitoring** — kube-prometheus-stack (Prometheus + Grafana + Alertmanager +
  node-exporter + kube-state-metrics) та StorageClass `gp3` на базі EBS CSI.
