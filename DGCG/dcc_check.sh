#!/bin/bash
#filename, country
json_dump=$(<"$1")

upload_length=$(echo $json_dump |jq 'map(select(.country == "'$2'" and .certificateType == "UPLOAD")) | keys | length')

#Az országkódra szűrt upload certeken végigmegyünk, és lerakjuk őket fileba (A DGC.CLI csak file-ból eszi meg)

begin="-----BEGIN CERTIFICATE-----"$"\n"
end="-----END CERTIFICATE-----"$"\n"
x=1
echo "Country $2 has $upload_length Upload certificates"

while [[ $x -le $upload_length ]]
do

  upload_cert_raw=$(echo $json_dump |jq 'map(select(.country == "'$2'" and .certificateType == "UPLOAD")) | .['$x-1'].rawData')
  upload_cert_raw=$(echo "$upload_cert_raw" | sed 's/^.//;s/.$//')
  upload_cert_file="$begin$upload_cert_raw"$"\n""$end"
  echo -e $upload_cert_file > $2_upload_$x.cert

  x=$(( $x + 1 ))
done

#Az országkódokra szűrt DSC certeken megyünk végig a korábban generált upload certekkel
#speed up. For ciklus előtt leszűrjük a listát)

dsc=$(echo $json_dump |jq 'map(select(.country =="'$2'" and .certificateType == "DSC"))')
dsc_length=$(echo $dsc |jq 'keys | length')
echo "Country $2 has $dsc_length DSC certificates"
#echo ${dsc[@]}

y=1
while [[ $y -le $dsc_length ]]
do
  dsc_cert_raw=$(echo $dsc |jq ' .['$y-1'].rawData')
  dsc_cert_raw=$(echo "$dsc_cert_raw" | sed 's/^.//;s/.$//')
  dsc_cert_sig=$(echo $dsc |jq ' .['$y-1'].signature')
  dsc_cert_sig=$(echo "$dsc_cert_sig" | sed 's/^.//;s/.$//')
  dsc_cert_kid=$(echo $dsc |jq ' .['$y-1'].kid')
  dsc_cert_kid=$(echo "$dsc_cert_kid" | sed 's/^.//;s/.$//')
  dsc_cert_thumb=$(echo $dsc |jq ' .['$y-1'].thumbprint')
  dsc_cert_thumb=$(echo "$dsc_cert_thumb" | sed 's/^.//;s/.$//')

  this_dsc_has_upload=0

#Végigmegyünk az összes upload certen
        z=1
        while [[ $z -le $upload_length ]]
        do
          result=$(java -jar dgc-cli.jar signing validate-cert -s $dsc_cert_sig -ps $dsc_cert_raw -c $2_upload_$z.cert| grep "Matches Given Certificate")
          upload_exp_date="$(date --date="$(openssl x509 -enddate -noout -in "$2_upload_$z.cert"|cut -d= -f 2)" --iso-8601)"
#         dsc_exp_date="$(echo -ne "$begin$dsc_cert_raw"$"\n""$end")"
#         dsc_exp_date="$(date --date="$(echo "$dsc_exp_date" | openssl x509 -enddate -noout | cut -d= -f 2)" --iso-8601)"
          dsc_exp_date="$(date --date="$(echo -ne "$begin$dsc_cert_raw"$"\n""$end" | openssl x509 -enddate -noout | cut -d= -f 2)" --iso-8601)"

          if [[ $result == *yes* ]]; 
          then
                  echo "$y $dsc_cert_kid DSC expires at $dsc_exp_date and signed upload which expires $upload_exp_date"
                  this_dsc_has_upload=1
                  break
          fi
          
          z=$(( $z +1 ))

        done

        if [[ $this_dsc_has_upload -lt 1 ]];
        then
            echo "$y $dsc_cert_kid has no belonging upload cert in the DB!!! $dsc_cert_thumb"
        fi

  y=$(( $y +1 ))
done
