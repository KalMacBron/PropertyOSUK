# PropertyOS marketing site

This directory contains the static public site published at
<https://propertyosuk.com>. The private Flutter Alpha remains separately
deployed at <https://alpha.propertyosuk.com>.

Changes are deployed from `main` by `deploy-marketing.yml`. The workflow uses a
marketing-specific FTP state file so it does not manage or remove the Alpha
application under `/public_html/alpha/`.

The checked-in screenshots contain no tenant names, property addresses or other
portfolio-identifying information.
