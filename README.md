"tw_user_analyzer.sh" is used to extract following and follower from Twitter Accounts and generate analysis charts.

This script is based on twurl and Twitter API, so you need to register a Twitter Developer Account first and create a project.

Get twurl from here "https://github.com/twitter/twurl"

This tools support multi-processes, if you have more than one twitter accounts, you can use twurl to register them on your twitter project.

"twurl accounts" will show you all registered accounts

<img src="/screenshot/2021-01-10_12-08-27.jpg">

<img src="/screenshot/2021-01-10_00-06-27.jpg">


In the "targets.list" I'll use @zlj517 and @SpokespersonCHN as examples.

<img src="/screenshot/%E5%8D%8E%E6%98%A5%E8%8E%B9.jpg">

<img src="screenshot/%E8%B5%B5%E7%AB%8B%E5%9D%9A.jpg">

<img src="/screenshot/zlj_vs_hcy.jpg">


Don't forget install jq and json-query, I already uploaded the json_query-0.0.2-py2-none-any.whl

After install the json-query need to use vi to edit /usr/local/bin/json-query like following:

```
#!/usr/bin/python
# -*- coding: utf-8 -*-
import re
import sys

from jsonquery.jsonquery import main

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw?|\.exe)?$', '', sys.argv[0])
    sys.exit(main())
```
