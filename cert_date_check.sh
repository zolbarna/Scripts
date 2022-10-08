for pem in ./$1/*.pem; do 
   printf '%s %s\n' \
      "$(date --date="$(openssl x509 -enddate -noout -in "$pem"|cut -d= -f 2)" --iso-8601)" \
      "$pem"
done | sort
