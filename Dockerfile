# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM alpine

RUN apk add --update \
    curl openssl jq bash ca-certificates \
    && rm -rf /var/cache/apk/

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl

WORKDIR /opt/apigee
COPY  restart.sh /opt/apigee

RUN addgroup -g 20000 apigee && adduser -D -h /opt/apigee --shell /usr/local/bin/bash -u 20001 -G apigee apigee && chown -R 20001:20000 /opt/apigee

USER 20001

CMD ["/opt/apigee/restart.sh"]

