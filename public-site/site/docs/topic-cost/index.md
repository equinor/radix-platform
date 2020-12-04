---
title: Radix Cost
layout: document
parent: ['Docs', '../../docs.html']
toc: true
---

# Radix cost allocation

As part of hosting an application on Radix, each application will take it's share of the cloud cost assosiated with the Radix Production cluster. The cost will be allocated monthy following the routines issued by Equinor.

## How is the cost calculated

The cost is split according to memory and CPU requested (specified in the radixconfig.yaml) for all environments in the application. These source values are recorded every hour, together with the total memory and CPU for the cluster. At the end of the month the hourly numbers for each application is accumulated and the cluster cost for the month is distributed per application by the percentage.


### Sample

Assuming only these few applications

**Registration at 13:00**  
Application A - CPU: 1000m - Memory: 128Mi  
Application B - CPU: 500m - Memory: 128Mi  

Total - CPU: 10000m - Memory: 1000Mi  

**13:00 Calculation**  
Application A - CPU: 66% - Memory: 50% = (66% + 50%)/2 = 58%  
Application B - CPU: 34% - Memory: 50% = (34% + 50%)/2 = 42%  

**Registration at 14:00**  
Application A - CPU: 500m - Memory: 64Mi  
Application B - CPU: 500m - Memory: 128Mi  
Application C - CPU: 1000m - Memory: 256Mi

Total - CPU: 10000m - Memory: 1000Mi  

**14:00 Calculation**  
Application A - CPU: 25% - Memory: 14% = (25% + 14%)/2 = 19,5%  
Application B - CPU: 25% - Memory: 29% = (25% + 29%)/2 = 27%  
Application C - CPU: 50% - Memory: 57% = (50% + 57%)/2 = 53,5%  

And so on...
