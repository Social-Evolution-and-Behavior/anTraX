function s = hostname()


s = char(java.net.InetAddress.getLocalHost.getHostName);
s = strsplit(s,'.');
s = s{1};
