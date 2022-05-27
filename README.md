<h1 style="text-align:center">Integrationhub Helper Scripts</h1>

# Getting Started

In order to use the Integration Hub helper scripts, they will need to be added to your path.

If you're on windows, you may also need to add a zip command to your bash interpreter. We've often used https://github.com/bmatzelle/gow, but of course any command which will construct a zip should work. If you do use a different command (bzip or 7zip, for instance, you might need to modify your local uploadResourceCollection.sh and uploadRecipe.sh scripts to use your new zip command), unless that command also answer to 'zip' and uses the same argument structure as the normal terminal zip.

You should execute these scripts from the root of the ihub-partner-? repos

These scripts require that you create a creds folder (by default, in ~/creds - please remember that this will hold credentials, so put it in a safe place. If you override the location of the creds directory, please modify setEnvForUpload.sh to change the **$CREDS_DIR** location), which contains filesets for each of the flow servers you want to interact with:

### **$ALIAS**.token

_(mandatory)_
This should contain the token returned from the flow server at https://**$FLOW_SERVER**/auth/s2s/token/create
This endpoint is only available after logging in, and creates a token which grants the same permissions as the logged-in user at the time of creation. By default, these tokens have a 30 day expiry, unless expired manually earlier, or the flow server is configured with a longer expiry.

example:

> F123656716395350R1CV_1617054465218

### **$ALIAS**.flow

_(optional)_
If the flow server is not found at https://flow.$ALIAS.ucroo.org, this file should exist and contain the url to the root of the flow server (scheme, domain, port if necessary). If you do not wish to override the flow server's url, ensure that this file does not exist in the creds directory.

example:

> https://flow.my.uni.ucroo.edu

### **$ALIAS**.curl

_(optional)_
If any additional CURL arguments need to be sent on requests to the flow server, then they should be added here. For instance, if you have the flow server behind some network infrastructure which requires certain headers to be added.

example:

> --insecure -H "X-ROUTER: unirouter-1"

### **$ALIAS**.api

_(optional)_
If the campus portal API host is not found at https://api.$ALIAS.ucroo.org, this file should exist and contain the url to the root of the api server (scheme, domain, port if necessary). If you do not wish to override the api server's url, ensure that this file does not exist in the creds directory.

example:

> https://api.my.uni.ucroo.edu

</br>

# Next Steps

These scripts are written in bash. Scripts require certain arguments. Below are instructions with examples for some of the more popular scripts.

<details>
<summary><b>uploadSharedConfig</b></summary>
<b>Action:</b> Uploads all shared config objects within the JSON file specified within the project flow directory to the environment specified.

<b>Instruction:</b> to be called from the root of the project.

<b>Example:</b>

> uploadSharedConfig.sh uni uni

<b>Notes:</b> If you want to upload to local development, leaving off the 2nd argument default to local staging.

</details>
</br>
<details>
<summary><b>uploadFlow</b></summary>
<b>Action:</b> Uploads all flow objects within the JSON file specified within the project flow directory to the environment specified.

<b>Instruction:</b> to be called from the root of the project.

<b>Example:</b>

> uploadFlow.sh uni uni

<b>Notes:</b> If you want to upload to local development, leaving off the 2nd argument default to local staging.

</details>
</br>
<details>
<summary><b>uploadTrigger</b></summary>
<b>Action:</b> Uploads all trigger objects within the JSON file specified within the project flow directory to the environment specified.

<b>Instruction:</b> to be called from the root of the project.

<b>Example:</b>

> uploadTrigger.sh uni uni

<b>Notes:</b> If you want to upload to local development, leaving off the 2nd argument default to local staging.

</details>

# Downloading Flow Entities

If you need to download all of a flow server's entities (flows, resources, triggerers, shared config), then run the following script:

```
downloadFlowEntities.sh ENV
```

This will create a `src` directory in the directory where you ran the script containing all of the flow's entities.

Note: This script requires `python3`.
