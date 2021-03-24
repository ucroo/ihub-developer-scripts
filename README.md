# ihub-scripts
Integration Hub helper scripts

This should be added to your path.

You should execute these scripts from the root of the ihub-partner-? repos

These scripts require that you create a creds folder (by default, in ~/creds - please remember that this will hold credentials, so put it in a safe place.  If you override the location of the creds directory, please modify setEnvForUpload.sh to change the **$CREDS_DIR** location), which contains filesets for each of the flow servers you want to interact with:

### **$ALIAS**.username *(mandatory)*
This should contain the username of the user you use to login to flow

example:
> admin@uni.ucroo.com
	
### **$ALIAS**.password *(mandatory)*
This should contain the password of the user you use to login to flow

example:
> ch@ng3m3

### **$ALIAS**.flow *(optional)*
If the flow server is not found at https://flow.$ALIAS.ucroo.org, this file should exist and contain the url to the root of the flow server (scheme, domain, port if necessary).  If you do not wish to override the flow server's url, ensure that this file does not exist in the creds directory.

example:
> https://flow.my.uni.ucroo.edu

### **$ALIAS**.curl *(optional)*
If any additional CURL arguments need to be sent on requests to the flow server, then they should be added here.  For instance, if you have the flow server behind some network infrastructure which requires certain headers to be added.

example:
> --insecure -H "X-ROUTER: unirouter-1"

### **$ALIAS**.api *(optional)*
If the campus portal API host is not found at https://api.$ALIAS.ucroo.org, this file should exist and contain the url to the root of the api server (scheme, domain, port if necessary).  If you do not wish to override the api server's url, ensure that this file does not exist in the creds directory.

example:
> https://api.my.uni.ucroo.edu
