# Authentication

Equinor uses Azure AD for authentication of applications hosted outside Equinor internal network. Azure AD is synced with Equinor internal AD, and contains information on Equinor users and groups++. 

When doing authentication for applications and apis hosted outside Equinor internal network, we use OAuth 2.0 protocol and OpenId Connect. Information on these protocols can be found at [Microsoft documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-overview) or a more compact explination by Equinor [Nils Hofseth Andersen](https://equinor.github.io/mss-architecture/oauth2/openid/2019/08/22/oauth2-basics-playground.html). 

Radix does not support any authentication for your application out of the box, but we'll go through some scenarios and describe how this can be added. 

**The rest of this document assumes you have basic knowledge of OAuth 2.0, OpenId Connect and JWT tokens.**

## Client authentication

### Oauth-proxy

Its possible to use a proxy in front of the client application that takes care of the authentication flow. This can be introduced to any existing components, and is a good alternative if you have an old web application where you do not want to implement authentication in the client itself. 

!!IMAGE 

In the end this will create a JWT token which can be used to call other resouces (e.g. API). 

### Directly in client

There are several examples out there on how to implement this for different clients, Microsoft provides a set:
https://github.com/Azure-Samples/?utf8=%E2%9C%93&q=active-directory&type=&language=

Equinor also have a template for developing Single page ReactJS applications: https://github.com/equinor/videx-react-template

## API authentication

In general its recommended (by software development security adivisor) that any API should be responsible for access control of its own endpoints. This indicates that all requests to an API should be authenticated and authorized from inside the API, and not by a proxy in front of the API. 

## Client-API requests

## API-API authentication

