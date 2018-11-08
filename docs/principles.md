TODO: A few dangling questionmarks in this article. Should probably be updated.

We have defined a set of principle and use these as guidance when working to define the software development platform. The principles will evolve as we experiment and learn. 

The platform will involve to key-actors; "software development teams" and "plattform team". The purpose of the software development plattform and the "plattform team", is to enable the software teams to develop and operate business functionality as efficient, fast and secure as possible. 

## Key principles - overall
  * If it can't be automated - we do not do it!
  * The cloud vendor foot print in our platform is extremely small - allowing us to easily extend platform between cloud vendors
  * The platform components should be replaceable without interrupting the end user experience
  * Teams owns their applications
  * Metrics is a key asset for platform and all apps


## The Software Development Platform

  * encourages containerised, often micro service based architecture
  * encourages the 12-factor apps methodology and principles (https://12factor.net/)
  * encourages the Cloud Native Initiative? (https://www.cncf.io/)
  * encourages a cloud vendor agnostic approach (cloud vendor fot print as small as possible)
  * encourages usage of and active contribution to open source
  * is primarily hosted outside Statoil Internal Network and Data Centers
  * is providing a fully automated platform for CI, "<sup>1</sup>Security testing", CD and application execution
  * is providing predefined services for monitoring and log management
  * is providing and advocating <sup>2</sup>smart software engineering practices
  * is using Statoil IAM for authentication

## Application front-ends

  * are running in moderns web browsers
  * are based on HTML5, CSS and JavaScript
  * are encourages to use the XXX framework ???

## Application back-ends

  * are using Linux as host platform
  * are using a <sup>3</sup>container based echo system
  * are encouraging the following programming languages XXX, YYY, ZZZ ???
  * are dis-encouraging the following programming languages for production: R, MathLab, SharePoint, ++ ???
  * are encouraging communication using HTTP(S)/REST, Event Queues (MQTT/AMQP), Web Sockets and OpcUA over SOAP-HTTPS.

## Storage

  * are preferably consumed as a service
  * are encouraging exposing data using API's provided by the application 
  * back-end (and SDK fromt he "owner" back-end to the data)
  * are dis-encouraging implementing business logic at storage/db level
  * are dis-encouraging direct links between databases.


----
<sup>1</sup> Security testing could be testing against OWASP, Fuzzy testing, Open Source license status, Libraries to know CVE's ...
<sup>2</sup> Smart Software Engineering Practices could be testing, code review, process in version control (push/pull)
<sup>3</sup> Container Echo system. Containers, like Docker that adheres to a standard contract/interface for logging, health data and service discovery