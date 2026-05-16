#!/bin/bash
ANON='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzc4ODM1OTg0LCJleHAiOjIwOTQxOTU5ODR9.r78z4OSi_z2fQNQzMq8rsrLCSDQMrJ-61HLNDKvOZf4'
SVC='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3Nzg4MzU5ODQsImV4cCI6MjA5NDE5NTk4NH0.llf1XqOcQNo5bwyNbuByyphu-vcwQuu2S-cmo37d9kE'
JWT='82b0c60f27fc949ca9370676c7fc84b62ec0c1941d18ec44a058f945ca6a2923'
ENV=/opt/supabase/supabase/docker/.env

sed -i "s|^ANON_KEY=.*|ANON_KEY=$ANON|" $ENV
sed -i "s|^SERVICE_ROLE_KEY=.*|SERVICE_ROLE_KEY=$SVC|" $ENV
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT|" $ENV
sed -i "s|^PGRST_JWT_SECRET=.*|PGRST_JWT_SECRET=$JWT|" $ENV

echo "Keys updated. Restarting Supabase..."
cd /opt/supabase/supabase/docker
docker-compose down
docker-compose up -d
echo "Done!"
