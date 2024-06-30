# Zero touch Azure Application registration client secret rotation

This project illustrates the process of configuring automated client secret rotation for [Azure AD app registrations](https://learn.microsoft.com/en-us/azure/active-directory/develop/active-directory-how-applications-are-added) using [Azure Functions](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-java?tabs=bash%2Cconsumption) (implemented in python). It integrates [Key Vault](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-overview) with Event Grid to provide notifications when secrets are nearing expiration.

![architecture](./SecretRotationArchitecture.png)

1. Key Vault is set up to send an Event Grid notification when a secret is approaching its expiration date (30 days prior by default).
2. An Azure Function is triggered by this Event Grid notification.
3. The Azure Function generates a new client secret for the Azure AD app registration.
4. The Azure Function updates the secret in Key Vault with the new client secret.


## Prerequisites

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
- Python installed on machine for locally running the Azure Function
- Azure subscription & resource group
- Azure AD Application Administrator role is needed by the user or identity running the Terraform script to manage all aspects of app registrations and enterprise apps, including assignments.


## Deployment the infrastructure

1.  Modify the `./infra/env/dev.tfvars` file to match your environment.

1.  Run the following command to deploy the initial infrastructure to Azure.

```shell
cd infra
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

1.  Update the `./src/java/pom.xml` file to match your environment (specifically the `functionAppName`, `resourceGroup`, `appServicePlanName` and `region` keys)

1.  Build & deploy the Azure Function Java code.

```shell
cd src/java
mvn clean package
mvn azure-functions:deploy
```

1.  Deploy the Event Grid subscription now that an endpoint exists in Azure Functions.

```shell
cd ../..
az deployment group create -g rg-keyVaultJava-ussc-dev --template-file ./infra/subscription/main.bicep --parameters ./infra/env/dev.parameters.json
```

1.  Create a test App Registration to be managed by the Azure Function in Azure Active Directory. Take note of the `objectId` of the App Registration.

1.  Retrieve the **Object Id** of the Managed Identity.

```shell
az identity show -g rg-keyvaultJava-ussc-dev -n mi-keyVaultJava-ussc-dev --query principalId
```

1.  Run the following command to assign the Managed Identity ownership over a test app registration (the **id** is the objectId of the app registration, the **owner-object-id** is the objectId of the Managed Identity).

1.  Run the following command to assign the Managed Identity the `Application.ReadWrite.OwnedBy` permission on the Graph API so it can update the client secrets on any app registration it owns (the **spId** is the objectId of the Managed Identity)

## Run the code

1.  Navigate to the test App Registration in the Azure portal. Copy the **objectId** of the App Registration.

1.  Click on **Certificates & secrets**.

1.  Click on **New client secret**.

1.  Enter a description and click **Add**.

1.  Copy the **id** & **value** of the secret.

1.  Navigate to the Key Vault in the Azure portal.

1.  Click on **Secrets**

1.  Click on **Generate/Import**

1.  Set the name of the secret to the **objectId** of the App Registration.

1.  Set the value of the secret to the **value** of the secret.

1.  Set the **Content Type** to the **id** of the secret (not of the App Registration, but of the secret itself).

1.  Set the **Expiration date** to a date in the near future (less than 30 days from now).

1.  Click **Create**.

1.  Wait a few minutes for Key Vault to send the notification to the Azure Function.

1.  Navigate back to the App Registration in the Azure portal.

1.  Click on **Certificates & secrets**.

1.  Notice that the secret has been replaced by a new one. Note the first 3 characters of the **Value** and the **Expires** value.

1.  Navigate back to the Key Vault in the Azure portal.

1.  Click on **Secrets**

1.  Click on the secret.

1.  Notice that a new secret version has been created. If you open it, you will see the new **secret value** and **expiration date** 1 year in the future.
