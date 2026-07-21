# Deployment runbook + докази деплою

Покроковий запуск усього стека на AWS і збір скріншотів/логів (пункт 6).

> ⚠️ Це піднімає реальні платні ресурси (EKS control plane, 2× t3.medium,
> NAT Gateway, RDS, ELB, EBS). Після зняття скріншотів виконайте
> `terraform destroy`, щоб не платити зайве.

## 0. Передумови

- Встановлено: `terraform >= 1.5`, `awscli`, `kubectl`, `helm`, `docker`.
- Налаштовані AWS-креденшели (`aws configure` / SSO) на потрібний акаунт і регіон
  `us-west-2`.
- Пароль БД у змінній середовища (у git не зберігається):
  ```bash
  export TF_VAR_db_password='ChangeMe-Strong-Pass-123'
  ```

## 1. Розв'язати колізію S3-бекенду (ОБОВ'ЯЗКОВО)

`module.s3_backend` створює бакет `terraform-state-bucket-001001` і таблицю
`terraform-locks`. Якщо вони вже існують від попередніх ДЗ — `apply` впаде.
Оберіть один варіант:

- **A. Свій унікальний бекенд (рекомендовано).** У `main.tf` змініть
  `bucket_name`/`table_name`, у `backend.tf` — `bucket`/`dynamodb_table` на
  унікальні імена, далі зробіть бутстрап (крок 2).
- **B. Перевикористати наявний бекенд.** Приберіть блок `module "s3_backend"` з
  `main.tf` (і відповідні виводи) — бакет/таблиця вже існують, а `key` у
  `backend.tf` («final-project/terraform.tfstate») і так окремий. Тоді крок 2
  пропускається.

## 2. Бутстрап бекенду (лише для варіанта A, перший запуск)

```bash
# 1) тимчасово закоментувати блок backend "s3" у backend.tf
terraform init
terraform apply -target=module.s3_backend | tee docs/logs/00-backend.log
# 2) розкоментувати backend "s3" і мігрувати стейт
terraform init -migrate-state
```

## 3. Запушити final-project у гілку main

Argo CD і Jenkins тягнуть Helm-чарт і `Jenkinsfile` зі шляху
`final-project/...` гілки `main` репозиторію. Без цього Argo не знайде чарт.

```bash
git checkout main
git merge final-project        # або зробіть PR і змерджте
git push origin main
```

## 4. Розгортання інфраструктури

Провайдери kubernetes/helm конфігуряться з даних EKS, тож мережу + кластер
піднімаємо першими, потім усе інше.

> ⚠️ У першому кроці цілимося одразу і в `module.vpc`, і в `module.eks`.
> `-target=module.eks` наодинці створює лише VPC + підмережі (те, на що EKS
> посилається), але **пропускає NAT Gateway, IGW і таблиці маршрутів** — і тоді
> ноди в приватних підмережах не мають виходу в інтернет і не приєднуються до
> кластера. `-target=module.vpc` створює мережевий модуль повністю.

```bash
terraform init
terraform apply -target=module.vpc -target=module.eks | tee docs/logs/01-eks.log
terraform apply | tee docs/logs/02-apply-full.log
```

Підключити kubectl:

```bash
aws eks update-kubeconfig --region us-west-2 --name final-project-eks
kubectl get nodes | tee docs/logs/03-nodes.log
```

## 5. Зібрати й запушити образ Django в ECR

Щоб застосунок реально піднявся (Argo деплоїть образ `:latest`):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region us-west-2 \
  | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com

docker build -t ${REPO_URL}:latest .
docker push ${REPO_URL}:latest | tee docs/logs/04-ecr-push.log
```

> Пізніше те саме робить Jenkins-пайплайн автоматично (Kaniko → ECR → bump tag →
> Argo sync) — це можна показати окремим скріншотом успішного білду.

## 6. Перевірка стану компонентів (зберегти в логи)

```bash
kubectl get all -n jenkins     | tee docs/logs/10-jenkins.log
kubectl get all -n argocd      | tee docs/logs/11-argocd.log
kubectl get all -n monitoring  | tee docs/logs/12-monitoring.log
kubectl get pods,svc,hpa       | tee docs/logs/13-app.log
kubectl get hpa                # TARGETS має показувати %, не <unknown>
kubectl get storageclass       # gp3 (ebs.csi.aws.com)
kubectl get pvc -n monitoring  # томи Prometheus/Grafana у статусі Bound
```

## 7. Доступ до UI (для скріншотів) — кожне в окремому терміналі

```bash
# Jenkins  (логін admin)
kubectl -n jenkins port-forward svc/jenkins 8080:8080
terraform output -raw jenkins_admin_password

# Argo CD  (логін admin)
kubectl -n argocd port-forward svc/argocd-server 8081:443
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d

# Grafana  (логін admin)
kubectl -n monitoring port-forward svc/grafana 3000:80
terraform output -raw grafana_admin_password

# Prometheus
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
```

## 8. Що заскріншотити (кладіть у `docs/screenshots/`)

- [ ] `terraform apply` — рядок `Apply complete! Resources: N added`.
- [ ] `kubectl get nodes` — ноди у `Ready`.
- [ ] `kubectl get pods -A` або по namespace — усе `Running`.
- [ ] Django через ELB: `kubectl get svc django-app-django-app` → відкрити
      EXTERNAL-IP у браузері.
- [ ] Jenkins UI: успішний build джоби `django-app-ci` (зелений pipeline).
- [ ] Argo CD UI: застосунок `django-app` у статусі `Synced` / `Healthy`.
- [ ] Grafana: логін + дашборд Kubernetes з метриками (CPU/пам'ять).
- [ ] Prometheus: `Status → Targets` (up) або графік.
- [ ] `kubectl get hpa` з реальним % завантаження.

## 9. Прибрати за собою

```bash
terraform destroy | tee docs/logs/99-destroy.log
```

---

## Результати деплою

_Сюди вставте скріншоти (`![опис](docs/screenshots/файл.png)`) і за потреби
короткі витяги з логів із `docs/logs/`._
