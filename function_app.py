import logging
import datetime
from uuid import UUID
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from azure.graphrbac.models import PasswordCredential
from msgraph import GraphServiceClient
from msgraph.generated.applications.item.add_password.add_password_post_request_body import AddPasswordPostRequestBody
from msgraph.generated.models.password_credential import PasswordCredential
from msgraph.generated.applications.item.remove_password.remove_password_post_request_body import RemovePasswordPostRequestBody
import azure.functions as func

app = func.FunctionApp()

@app.event_grid_trigger(arg_name="azeventgrid")
async def KVEventGridTriggers(azeventgrid: func.EventGridEvent):
    logging.info('EventGrid trigger processed an event')
    event_data = azeventgrid.get_json()
    logging.info(event_data)
    key_vault_name = event_data['VaultName']

    if not key_vault_name:
        logging.error("Key Vault name not found in event data. Exiting function.")
        return
    
    key_vault_uri = f"https://{key_vault_name}.vault.azure.net/"

    # name of the app registration which is used as the secret name in Key Vault
    app_registration_object_id = event_data['ObjectName']

    credential = DefaultAzureCredential()
    secret_client = SecretClient(vault_url=key_vault_uri, credential=credential)

    try:
        previous_client_secret = secret_client.get_secret(app_registration_object_id)
        previous_client_secret_key_id = previous_client_secret.properties.content_type

        new_password_credential = await set_app_registration_client_secret(app_registration_object_id, previous_client_secret_key_id)

        if new_password_credential:
            logging.info(f"Updating secret in Key Vault for {app_registration_object_id} app registration.")
            secret_client.set_secret(app_registration_object_id, new_password_credential.secret_text, 
                                     content_type=str(new_password_credential.key_id),
                                     expires_on=new_password_credential.end_date_time)
    except Exception as e:
        logging.error(f"Error processing secret for app registration {app_registration_object_id}: {e}", exc_info=True)


async def set_app_registration_client_secret(app_registration_object_id, credential, previous_client_secret_key_id):
    graph_client = GraphServiceClient(credential)
    number_of_days_until_expiry = 60
    end_date_time = (datetime.datetime.now(datetime.UTC) + datetime.timedelta(days=number_of_days_until_expiry)).isoformat()

    add_password_request_body = AddPasswordPostRequestBody(
	password_credential = PasswordCredential(
		display_name = "Set via Azure Functions",
        end_date_time = end_date_time,
	),
        )
    
    removal_request_body = RemovePasswordPostRequestBody(
	        key_id = UUID(previous_client_secret_key_id),
                )

    try:
        logging.info(f"Rotating client secret for app registration: {app_registration_object_id}")
        new_password_credential = await graph_client.applications.by_application_id(app_registration_object_id).add_password.post(add_password_request_body)
        
        await graph_client.applications.by_application_id(app_registration_object_id).remove_password.post(removal_request_body)
    except Exception as e:
        logging.error(f"Error rotating client secret for app registration {app_registration_object_id}: {e}", exc_info=True)
        return None

    return new_password_credential
