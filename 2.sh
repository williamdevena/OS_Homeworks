#!/bin/bash

# VARIABILI USATE IN FUNZIONI
#trovato=0
declare -A dizionario_figli

# FUNZIONI
function controllo () { 
  #echo controllooooo
  trovato=0
  while [[ trovato -eq 0 ]]
  do
    #echo gggg
    for file in $PWD/*
    do
      filename=$(basename $file)
      if [ $filename == "done.txt" ]
      then
          #echo trovatoooo
          echo "File done.txt trovato" >&3
          if [ -e tmp_controllo ]
          then
              echo "trovato=1" > tmp_controllo
          fi
          trovato=1
          return
          break
      fi
    done
    if [[ trovato -eq 0 ]]
    then
        sleep $intero
    fi 
  done
}

function raccogli_pid () {
  pid=$1
  while [[ $(ps --ppid $pid | wc -l) -ne 1 ]] && [[ $trovato -eq 0 ]]
  do
    #echo raccogliii
    for el in $(ps --ppid $pid | awk 'FNR >1 {print $1}')
    do
      if [[ ! ${dizionario_figli[$pid]} =~ $el ]]
      then
          if [ -e tmp_raccogli ]
          then
              echo "dizionario_figli[$pid]+=$el/" >> tmp_raccogli
          fi
          dizionario_figli[$pid]+="$el/"
          raccogli_pid $el &
      fi
    done
    . tmp_controllo
  done
  #rm tmp_controllo
}

regex='^[0-9]+$'
filename=$(basename "$0")

# CONTROLLA CHE IL PRIMO ARGOMENTO è UN INTERO
if [[ $1 =~ $regex ]]
then
	intero=$1
else
	echo "Uso: s sampling commands files" >&2
	exit 15
fi

# SERVE A CONTROLLARE CHE CI SIA MINIMO UN COMANDO 
# E QUINDI CHE CI SIA UN ARG CON ",,,"
errore=1
# CREA LA LISTA DEI COMANDI, DOVE PERO I COMANDI 
# CON OPZIONI NON SONO SCRITTI CON LO SPAZIO MA
# CON "/" INFATTI DOPO BISOGNA USARE tr "/" " " <<< $el
lista=()
i=2
for arg in ${@:2}
do
  if [[ $arg =~ ",,," ]]
  then
  	  errore=0
  	  stringa+=${arg%%",,,"}
  	  lista+=($stringa)
  	  stringa=""
  	  indice=$i
  	  i=$[i+1] 	  
      break
  elif [[ $arg =~ ",," ]]
  then
  	  stringa+=${arg%%",,"}
      lista+=($stringa)
      stringa=""
  elif [ $arg == ",," ]
  then
      stringa-=","
      lista+=($stringa)
      stringa=""
  elif [ $arg == ",,," ]
  then
      errore=0
      stringa-=","
      lista+=($stringa)
      stringa=""
      indice=$i
      i=$[i+1]    
  else
  	  stringa+=$arg
  	  stringa+=","
  fi
  i=$((i+1))
done

if [[ $# -eq $indice ]]
then 
    errore=1
fi

if [[ $errore -eq 1 ]]
then
	echo "Uso: s sampling commands files" >&2
  #echo 15
	exit 15
fi

numero_file=$(( $# - $indice ))
if [[ $numero_file -ne $(( ${#lista[@]} * 2 )) ]]
then
	echo "Uso: s sampling commands files" >&2
  #echo 30
	exit 30
fi

# CREO LISTA_FILE
lista_file=()
indice=$((indice+1))
for arg in ${@:$indice}
do
  lista_file+=($arg)
done

# STAMPA I PID DEI PROCESSI SUL FILE DESCRIPTOR 3
touch tmp
lista_comandi=()
declare -A dizionario_out
declare -A dizionario_err
z=0
for el in "${lista[@]}"
do 
  indice_err=$((z+${#lista[@]}))
  comando=$(tr "," " " <<< $el)
  if [[ $(type $comando 2> /dev/null) ]]   # SE IL COMANDO NON ESISTE
  then
      el+=",1>${lista_file[$z]},2>${lista_file[$indice_err]},&"
      lista_comandi+=($el)
  fi
  z=$((z+1))
done


#echo ${lista_comandi[@]}
# ITERA LISTA_COMANDI
x=1
#z=0
lista_pid=()
for comando in "${lista_comandi[@]}"
do
    comando2=$(tr "," " " <<< $comando)
    eval $comando2
    testo=$!
    lista_pid+=($testo)
    if [[ x -ne ${#lista_comandi[@]} ]]
    then
        testo+="_"
    else
        testo+="\n"
    fi
    printf $testo >> tmp
    x=$((x+1))
done
#echo ${lista_pid[@]}
cat tmp >&3          #>&3            
rm tmp


# CONTROLLO SE TROVO done.txt NELLA CURRENT DIRECTORY
#trovato=0
touch tmp_controllo
chmod 777 tmp_controllo
touch tmp_raccogli
chmod 777 tmp_raccogli
controllo &
for pid in ${lista_pid[@]}
do
    raccogli_pid $pid &
done
while [[ trovato -eq 0 ]]
do  
  . tmp_controllo
done
. tmp_raccogli


touch tmp_foresta
for el in ${!dizionario_figli[@]}
do
  figli=$(tr "/" " " <<< ${dizionario_figli[$el]})
  for figlio in ${figli[@]}
  do
    echo $el $figlio >> tmp_foresta
  done
done
sort -n tmp_foresta >&1


touch tmp_err
exec 5>&2
exec 2> tmp_err
#echo cazzooo
for comando in ${lista_comandi[@]}
do
  comando=$(awk -F, '{print $1}' <<< $comando)
  comando=$(basename $comando)
  killall $comando &> /dev/null
done
#exec 2>&5 5>&-

rm tmp_err
rm tmp_controllo
rm tmp_foresta
rm tmp_raccogli
