# Infrastructure as Code Workshop
Welcome to the Infrastructure as Code workshop repository. This repo contains lab instructions (including a finished example version of each lab) for three different IaC tooling options for Azure deployments:
* Bicep
* Terraform
* Pulumi

In each lab, you will setup the same set of infrastructure resources in Azure , and validate your deployed infrastructure using a prebuilt web application along the way. This allows you to not only try out the different tooling options but also to compare the feature set and development workflow of each tool. At the end of the workshop, you should  have enough knowledge to be able to select the most suitable option for your companys infrastructure deployments.

![ActiveSolution_IAC_Workshop](https://user-images.githubusercontent.com/1662918/157407878-84bc4c16-411b-4281-935a-104f3b246f83.jpg)

> **Note**  
This workshop can be delivered on demand, and consists of a half-day of presentations and a half-day of lab excercises.
Please contact us at https://www.activesolution.se/ to schedule a workshop


## Lab content
The lab will setup the following type of resources:

- Azure App Service running on Linux
- Azure Key Vault for storing sensitive information, such as passwords
- Azure SQL Server and a SQL database
- Application Insights resource backed by a Log Analytics workspace

Here are the links to each lab:

* [Bicep lab](labs/bicep.md)
* [Terraform lab](labs/terraform.md)
* [Pulumi lab](labs/pulumi.md)
* [CI/CD Lab with Bicep and GitHub actions](labs/github-bicep.md)
