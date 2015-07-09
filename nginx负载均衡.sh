
Nginx之负载均衡

注，大家可以看到，由于我们网站是发展初期，nginx只代理了后端一台服务器，但由于我们网站名气大涨访问的人越来越多一台服务器实在是顶不住，于是我们加了多台服务器，那么多台服务器又怎么配置代理呢，之前是以LVS来做负载均衡,现在想试下nginx 我们这里以两台服务器为案例，为大家做演示。

2.upstream 负载均衡模块说明

下面设定负载均衡的服务器列表。

放在http{}块里面

upstream test.net{

ip_hash;

server 192.168.1.150:80;

server 192.168.1.161:80;

 

}

server {

  location / {

    proxy_pass  http://test.net;

  }
}

       upstream是Nginx的HTTP Upstream模块，这个模块通过一个简单的调度算法来实现客户端IP到后端服务器的负载均衡。在上面的设定中，通过upstream指令指定了一个负 载均衡器的名称test.net。这个名称可以任意指定，在后面需要用到的地方直接调用即可。

3.upstream 支持的负载均衡算法

Nginx的负载均衡模块目前支持4种调度算法，下面进行分别介绍，其中后两项属于第三方调度算法。  

·         轮询（默认）。每个请求按时间顺序逐一分配到不同的后端服务器，如果后端某台服务器宕机，故障系统被自动剔除，使用户访问不受影响。Weight 指定轮询权值，Weight值越大，分配到的访问机率越高，主要用于后端每个服务器性能不均的情况下。

·         ip_hash。每个请求按访问IP的hash结果分配，这样来自同一个IP的访客固定访问一个后端服务器，有效解决了动态网页存在的session共享问题。

·         fair。 这是比上面两个更加智能的负载均衡算法。此种算法可以依据页面大小和加载时间长短智能地进行负载均衡，也就是根据后端服务器的响应时间来分配请求，响应时 间短的优先分配。Nginx本身是不支持fair的，如果需要使用这种调度算法，必须下载Nginx的upstream_fair模块。

·         url_hash。此方法按访问url的hash结果来分配请求，使每个url定向到同一个后端服务器，可以进一步提高后端缓存服务器的效率。Nginx本身是不支持url_hash的，如果需要使用这种调度算法，必须安装Nginx 的hash软件包。

4.upstream 支持的状态参数

在HTTP Upstream模块中，可以通过server指令指定后端服务器的IP地址和端口，同时还可以设定每个后端服务器在负载均衡调度中的状态。常用的状态有：      

·         down，表示当前的server暂时不参与负载均衡。

·         backup，预留的备份机器。当其他所有的非backup机器出现故障或者忙的时候，才会请求backup机器，因此这台机器的压力最轻。

·         max_fails，允许请求失败的次数，默认为1。当超过最大次数时，返回proxy_next_upstream 模块定义的错误。

·         fail_timeout，在经历了max_fails次失败后，暂停服务的时间。max_fails可以和fail_timeout一起使用。

注，当负载调度算法为ip_hash时，后端服务器在负载均衡调度中的状态不能是weight和backup。


5.配置nginx负载均衡

upstream webservers {

      server 192.168.18.201 weight=1;

      server 192.168.18.202 weight=1;

  }

  server {

      listen       80;

      server_name  localhost;

      #charset koi8-r;

      #access_log  logs/host.access.log  main;

      location / {

              proxy_pass      http://webservers;

              proxy_set_header  X-Real-IP  $remote_addr;

      }
}

注，upstream是定义在server{ }之外的，不能定义在server{ }内部。定义好upstream之后，用proxy_pass引用一下即可。

6.重新加载一下配置文件

[root@xuan nginx]# service nginx reload

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading nginx:                                           [  OK  ]

7.测试一下

注，大家可以不断的刷新浏览的内容，可以发现web1与web2是交替出现的，达到了负载均衡的效果。

8.查看一下Web访问服务器日志

Web1:

[root@Host_1 ~]# tail /var/log/httpd/access_log

192.168.1.82 - - [04/Sep/2013:09:42:00 +0800] "GET / HTTP/1.0" 200 23 "-" "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)"

Web2:

先修改一下，Web服务器记录日志的格式。

[root@Host_2 ~]# vim /etc/httpd/conf/httpd.conf

LogFormat "%{X-Real-IP}i %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined

[root@xuan nginx]# service nginx reload

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading nginx:                                           [  OK  ]

接着，再访问多次，继续查看日志。

[root@Host_2 ~]# tail /var/log/httpd/access_log

192.168.1.82 - - [04/Sep/2013:09:42:00 +0800] "GET / HTTP/1.0" 200 23 "-" "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)"

注，大家可以看到，两台服务器日志都记录是192.168.1.82访问的日志，也说明了负载均衡配置成功。

9.配置nginx进行健康状态检查

·         max_fails，允许请求失败的次数，默认为1。当超过最大次数时，返回proxy_next_upstream 模块定义的错误。

·         fail_timeout，在经历了max_fails次失败后，暂停服务的时间。max_fails可以和fail_timeout一起使用，进行健康状态检查。

[root@nginx ~]# vim /etc/nginx/nginx.conf

upstream test.net {

  server 192.168.18.201 weight=1 max_fails=2 fail_timeout=2;

  server 192.168.18.202 weight=1 max_fails=2 fail_timeout=2;
    }

10.重新加载一下配置文件

[root@xuan cache]# service nginx reload

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading nginx:                                          [  OK  ]

11.停止服务器并测试

[root@Host_1 httpd]# service httpd stop
Stopping httpd:                                            [  OK  ]

注，大家可以看到，现在只能访问Web2，再重新启动Web1，再次访问一下。

[root@Host_1 httpd]# service httpd start

Starting httpd: httpd: Could not reliably determine the server's fully qualified domain name, using 192.168.1.117 for ServerName                         [  OK  ]

注， 大家可以看到，现在又可以重新访问，说明nginx的健康状态查检配置成功。但大家想一下，如果不幸的是所有服务器都不能提供服务了怎么办，用户打开页面 就会出现出错页面，那么会带来用户体验的降低，所以我们能不能像配置LVS是配置sorry_server呢，答案是可以的，但这里不是配置 sorry_server而是配置backup。

12.配置backup服务器

[root@nginx ~]# vim /etc/nginx/nginx.conf

server {

                listen 8080;

                server_name localhost;

                root /tmp/error;

                index index.html;

        }

upstream test.net {

     server 192.168.1.150 weight=1 max_fails=2 fail_timeout=2;

     server 192.168.1.161 weight=1 max_fails=2 fail_timeout=2;

     server 127.0.0.1:8080 backup;

}

13.重新加载配置文件

[root@xuan error]# service nginx reload

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading nginx:                                          [  OK  ]

14.关闭Web服务器并进行测试

[root@Host_1 httpd]# service httpd stop

Stopping httpd:                                            [  OK  ]

[root@Host_2 tmp]# service httpd stop
Stopping httpd:                                            [  OK  ]

注，大家可以看到，当所有服务器都不能工作时，就会启动备份服务器。好了，backup服务器就配置到这里，下面我们来配置ip_hash负载均衡。

15.配置ip_hash负载均衡

·         ip_hash，每个请求按访问IP的hash结果分配，这样来自同一个IP的访客固定访问一个后端服务器，有效解决了动态网页存在的session共享问题。（一般电子商务网站用的比较多）

[root@nginx ~]# vim /etc/nginx/nginx.conf

upstream webservers {

        ip_hash;

        server 192.168.18.201 weight=1 max_fails=2 fail_timeout=2;

        server 192.168.18.202 weight=1 max_fails=2 fail_timeout=2;

        #server 127.0.0.1:8080 backup;
    }

注，当负载调度算法为ip_hash时，后端服务器在负载均衡调度中的状态不能有backup。（有人可能会问，为什么呢？大家想啊，如果负载均衡把你分配到backup服务器上，你能访问到页面吗？不能，所以了不能配置backup服务器）

16.重新加载一下服务器

[root@xuan tmp]# service nginx reload

nginx: the configuration file /etc/nginx/nginx.conf syntax is ok

nginx: configuration file /etc/nginx/nginx.conf test is successful
Reloading nginx:                                          [  OK  ]
nginx的负载均衡就全部演示到这里