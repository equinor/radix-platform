# Azure AD Authentication

A quick overview on setting up Azure AD authentication for your app.

First, set up the application in Azure Portal:

  * Azure Active Directory
  * App registrations
  * New application registration

Retrieve the Application ID from the new application. This will be used in your
code when creating an authentication context. For instance, if using [Adal.js](https://github.com/AzureAD/azure-activedirectory-library-for-js):

    const authContext = new AuthenticationContext({ clientId: MY_APP_ID });

If this application needs access to other systems we need to add those to the
"API Access" section. API access can be done via "required permissions" or
"keys". Still in Azure Portal:

  * Select the application
  * Settings
  * Required permissions (or keys)

Required permissions transparently grant access (via JWT) into other
applications when a user logs in to our application. "Keys" are pre-shared
secrets or public/private key pairs that are used for inter-application
authentication, when there are no users.

After having added the required permissions, a front-end application would
request a token access the other application (via Adal.js):

    authContext.acquireToken(OTHER_APP_ID, callback)
