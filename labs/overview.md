	• Prereqs
		○ Install tools (Azure CLI, bicep CLI, pulumi etc..)
		○ Check version
		○ Verify access (need subscription contributor access)
		
	• Getting started
		○ Authenticate
		○ Pulumi/Terraform: setup state management

	• App service plan + app service
		○ Deploy
		○ Check web app name in portal or with azure cli
		○ Browse to application. Verify keyvault connection string is missing
		
	• Add keyvault + app setting for keyvault
		○ Redeploy
		○ Verify keyvault access missing
	
	• Add vault access policy
		○ Redeploy
		○ Vault access works
		○ Verify Database connection string missing
		
	• Add SQL
		○ sql server
		○ sql database
		○ connection string in web app (requires AD Admin access!)
		○ Manually add sql server credentials to vault

		○ Redeploy template FAILS
			○ (Bicep) add templateddeployment
			○ (Pulumi/TF): access policy för "min" användare

		○ Redeploy WORKS
		○ Verify database access works
		○ Verify app insights setting is missing
		○ 
		
	• Add workspace and app insights + app settings in app service
		○ Redploy
		○ EVERYTHING WORKS!!!!
		
	• Add output variable for web app

		
	• Extra lab step 1
		○ Modularize template by extracting app service and app insights into a separate module / linked templte
To avoid admin acess: add unique user in database (using deployment scripts or similar)