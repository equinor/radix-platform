# Radix user adoption strategy

The goal of Radix is to increase efficiency, improve development practices and ultimately developer happiness inside Equinor.

We will not force people to use Radix but create an experience that is so good people use it voluntarily.

Active users and active application deployments can be used as proxies for the success of Radix internally.

However, converting a person who is unaware of Radix into a happy recurring active user is not necessarily easy.

# Methodology

## Thinking like a startup

When developing and marketing a product internally we have a lot to learn from what startups does. One definition of startup is “A startup is a company working to solve a problem where the solution is not obvious and success is not guaranteed” (https://www.forbes.com/sites/natalierobehmed/2013/12/16/what-is-a-startup/#19abea444044). If we replace the word company with team I think it describes us fairly well.

What separates us from a regular startup is that we do not have to worry about investments to fund development and selling the product later is easier since it's essentially free for our potential users.

Dave McClure created in 2007 the first general framework for approaching user adoption in a structured and measurable way: https://www.slideshare.net/dmc500hats/startup-metrics-for-pirates-long-version

In short, the AARRR funnel describes the journey from a customer who is unaware of our product to an active happy customer who helps market our product to others.

## Phase 0 - Awareness

At this point our customer does not know we exist or how we can help them.

We create awareness of our product by broadcasting our existence and our features. 

Suggestions: Intranet, Slack, conferences, blogs, internal campaigns, courses

## Phase 1 - Aquistition

Our potential customer takes the first active step towards learning more about the product.

There are several things our potential customer can do that shows they are interested, some showing a relatively low interest level and some showing a high interest level.

From low to high:

  * User visits our landing page
  * User spends some time on the landing page, maybe visiting sub-pages (features, documentation, getting started)
  * User joins our slack channels
  * User asks for permission to Radix
  * User asks for permission to our GitHub repos

## Phase 2 - Activation

Now our customer has learned about our platform and made the decision to try it out for real.

Ideally we want our customer to progress through the user journey and end up with building and deploying their software to Radix. To reach that the user have to accomplish several steps. There are also additional steps the users can do that shows an even greater interaction with the product.

Necessary:

  * Log on to Radix Web Console
  * Create an application
  * Set up connection to GitHub
  * Create a radixconfig.yaml file
  * Commit code to GitHub to trigger build
  * See that build and deployment is successful

Additional:

  * Log on to Grafana to view out-of-the-box monitoring of their deployment
  * Enable monitoring of custom metrics
  * Create a custom dashboard in Grafana for their application
  * Use Radix API
  * Create feature requests on `radix-platform` repo

## Phase 3 - Retention

Our customer has now been successfully onboarded. If our customers expectations have been met so far we want them to use Radix as a habit and integrate it into their ongoing work process.

To help form this habit we can use various forms of reminders and incentives.
  * Drip campaign/lifecycle emails to new users on the 3rd, 7th and 30th day after activating encouraging them to take advantage of the platform with for example custom monitoring.
  * Status emails weekly or monthly
    * Number of builds/deployments last week
    * Build times last week, with trends
    * Application response times last week, with trends
    * Application resource usage last week, with trends
    * Application usage (requests)
    * Application request failure rate
  * Event based e-mails. Build success/failure.

We can also encourage users to reach goals that are in line with the overall organization objectives:

  * Add custom metrics
  * Add security
  * Make system horizontally scalable (for redundancy and performance)
  * Separation of state

This might be further improved by adding some simple gamification.

Metrics we can use to determine if a user is active:

  * User logs on to and uses web console or Radix API
  * User consults documentation
  * Application is built and deployed regularly
  * End-user traffic to the customer application
  * User uses Radix API

Comparing the number of users who were active in the beginning of the month and how many of them were still active in the end of the month gives us our Churn rate. A low churn rate is important and shows that we over time deliver on our customers expectations. A high churn rate is a warning sign.

## Phase 4 - Referral

If we succeed in converting people to active and happy customers it's likely that they are willing to return the favour and help advocate the product to their peers. Product referrals from peers have a much much higher conversion rate than other kinds of sales and marketing and requires much less effort.



# Implementation

Automated collection of metrics is key since that has the lowest required effort over time, and it's also essential when comparing metrics and trends that the collection methodology is kept stable over time.




