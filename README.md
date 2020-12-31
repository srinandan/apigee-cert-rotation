# apigee-cert-rotation

Apigee hybrid uses TLS/mTLS for communication between components like Message Processor (MP) and UDCA or Synchronizer and Message Processor and so on. This repo explores a strategy to automatically renew certificates at a fixed interval.

## Method

Apigee hybrid uses [cert-manager](https://docs.cert-manager.io/) to request certificate. cert-manager can be configured to issue certificate that are valid for a specific duration  and to renew the certificate before the expiry of the certificate. In the following example, the certificate is valid for 30 days and is renewed 1 day (24 hours) before expiry:

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: Certificate
metadata:
  name: zzz
  namespace: apigee
spec:
  commonName: zzz.apigee.svc.cluster.local
  dnsNames:
  - zzz.apigee.svc.cluster.local
  issuerRef:
    kind: ClusterIssuer
    name: apigee-ca-issuer
  secretName: zzz-tls
  # duration of 30 days
  duration: 30d
  # renew 24 hours before
  renewBefore: 24h  
  usages:
  - digital signature
  - key encipherment
  - client auth
  - server auth
```

Once certificates are renewed, their corresponding Kubernetes secret are also updated. Pods that depend on the secret for TLS need to be restarted upon updating the secret. To ensure Pods are restarted at the same frequency as renewing certificates, a [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) has been created.

**Important**: Ensure the cronjob schedule matches the certificate renewal times. In this example, both are set to 30 days.

## Install

* Generate Certificates

```bash
./generate-certificates.sh --org $ORG --envs env1,env2 --namespace apigee
```

Parameters: The org name, a comma separated list of environments and optionally, the namespace where apigee is installed.

* Build Restart container

This container contains the script to restart Apigee Deployments

```bash
export PROJECT_ID=my-project-id
docker build -t gcr.io/$PROJECT_ID/restart .
docker push gcr.io/$PROJECT_ID/restart
```

* Deploy CronJob

```bash
export PROJECT_ID=my-project-id
kubectl apply -f restart-cron-job.yaml
```

This manifest includes a ServiceAccount, Role, RoleBinding and a CronJob.

## Out of scope

This method does not apply to certificates used by the Ingress. Anthos Service Mesh (Istio)'s Ingress can also be [integrated](https://istio.io/latest/docs/ops/integrations/certmanager/) with cert-manager.

## Versions

* GKE 1.17
* Apigee hybrid 1.4
* cert-manager 1.0.4

___

## Support

This is not an officially supported Google product