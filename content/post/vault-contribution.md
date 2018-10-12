+++
title = "Vault Contribution"
date = 2016-10-06T16:47:26-04:00
draft = false
tags = []
categories = []

+++

As evident by my posts here I have been spending a lot of time testing and implementing Hashicorp [vault](http://vaultproject.io). In putting the MySQL backend through its test paces for our production environment I hit a limitation that was A major show stopper for my environment. Which through the beauty of open source I was able to improve the MySQL backend and get those changes merged in to the project. Yay for open source and [github](http://github.com). 

The general gist of the MySQL auth backend is, you let vault generate users and their passwords, grants etc. for you. These auto generated users have a limited life or lease. When the lease expires vault drops these user accounts from the database. If your build this in your codebase correctly you in effect will connect with a new one time username and password every time you open a connection to the database. Very good as far as user database user security is concerned.  Prior to vault 0.6.2 if you had a user with a specific host, rather than a wild card for a host, vault would fail to revoke this user from the database. For example if I had vault create a user `'some-random-name'@'%'` everything would work as expected. However, if I had a user `'some-random-name'@'10.2.2.2'` this would fail to revoke. 

I spent a good amount of time trying to figure out what I was doing wrong, because this just seemed weird. Maybe I had syntax wrong somewhere. Or maybe vault was coming from a restricted source IP that wasn't able to perform these actions. Maybe my "admin" user wasn't setup correctly. Unfortunate for me everything was correct but it still did not work. So I found myself thinking. 
> I know go, vault is written in go. Lets go figure out who the revocation process works to see what _I'm_ missing

Thanks to the great code search in github I was able to find where this was happening pretty quickly. Much to my surprise this is what I found 
```
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '" + username + "'@'%';
DROP USER '" + username + "'@'%'
```
Vault was hard coded to only drop users with a wild card for a host. Where I work we are pretty serious about security so we do not have any user accounts with wild card hosts. They all are attached so a specific host or at subnet. Fortunate for me I was able to find an open github issue describing this problem, but it had not been commented on in sometime. I asked if this was still an open issue. The project lead responded that it was and they weren't quiet sure when it would be completed. But they would accept pull requests to improve it. Based on that and a nice description of where to start making changes from the project lead I decided, why not give it a shot. 

After only a handful of hours coding I the change implemented and I was able to manually test it and it all worked as I hoped. I submitted my PR, first response was "need tests". Oops. In my excitement of actually making it work I forgot to added tests. So I did and after few days of back and forth on small changes in the code I'm delighted to say that as of vault 0.6.2 released October 5th, the MySQL auth backend now supports wild card hosts and non wild card hosts. 

For some details how it works. When you create a role for the backend to use you would provide a string that is your user creation SQL statements. This got attached to a key in vault that could be looked up later for generating users. Now there is an additional key `revoke_sql` that you can save `REVOKE` and `DROP` SQL statements in to. When the lease expires and vault attempts to revoke a user account. If the the `revoke_sql` statements are provided it uses those. If they are not it falls back to the default of revoking with a wildcard host. 

This has been a very fulfilling experience for me. First off, this is the first time of contributed anything meaningful to a project that is a widely used piece of software. This feels like a real accomplishment for me. Second and equally as important, after years of using open source projects for free I've finally been able to give back to the community in a way that embodies what is great about open source. The old cliche of 
> It is open source, if you don't like it you can make changes yourself

Actually became a reality for me, and that feels pretty great. I hope what I've contributed helps other people as it is helping me personally and in the work I do for my job. 