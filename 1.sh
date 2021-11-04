#!/bin/bash

# FUNZIONI USATE

function albero () {
  lista_file2=$(ls -a $1)
  #echo $1
  for file in ${lista_file2[@]}
  do
    if [ $file != "." -a $file != ".." ]
    then
        #echo $file
        filename=$(basename "$file")
        #echo $filename
        nomecompleto=$1
        nomecompleto+="/"
        nomecompleto+=$file
        if [ -d $nomecompleto ]
        then
            #echo $nomecompleto
            albero $nomecompleto $2 
        # elif [ -h $file ] && [[ "$filename" =~ "$2" ]]
        # then
        #     inode2=$(ls -i $file | awk '{print $1}')
        #     dizionario[$inode2]=$((dizionario[$inode2]+1))
        #     if [ ${dizionario[$inode2]} -eq 1 ]
        #     then
        #         dizionario_nomi[$inode2]+="$filename"
        #     elif [ ${dizionario[$inode2]} -gt 1 ]
        #     then
        #         dizionario_nomi[$inode2]+="/$filename"
        #     fi  
        #     puntato=$(ls -ld $file | awk '{print $11}')
        #     puntato=$(basename "$puntato")
        #     lista_puntati+=($puntato)
        #     lista_file+=($file)
        elif [ -f $nomecompleto -a ! -h $nomecompleto ] #&& [[ "$filename" =~ "$2" ]]
        then
            # echo bellaaaaa
            # echo $file
            # echo ""
            inode2=$(ls -i $nomecompleto | awk '{print $1}')
            dizionario[$inode2]=$((dizionario[$inode2]+1))
            if [ ${dizionario[$inode2]} -eq 1 ]
            then
                dizionario_nomi[$inode2]+="$filename"
            elif [ ${dizionario[$inode2]} -gt 1 ]
            then
                dizionario_nomi[$inode2]+="/$filename"
            fi  
            lista_file+=($nomecompleto)
            #trova $filename
            # if [[ "$filename" =~ "$2" ]] && [[ ${dizionario[$inode2]} -eq 1 ]] && [ $trovato -ne 1 ]
            # then 
            #     analizza $file $3
            # fi
        fi
    fi
  done
}

function trova() {
  trovato=0
  for el in ${lista_puntati[@]}
  do
    if [ $el == $1 ]
    then
        trovato=1
        break
    fi
  done
}


function analizza() { 
  filename=$(basename "$1")
  dimensione=$(ls -l $1 | awk '{print $5}')
  dimensione=$((dimensione%4))
  #echo $dimensione
  if [ $dimensione -eq 0 -o -h $1 ]
  then
      testo=$(xxd -pu -c 1000000 $1 | grep -o -b $2 | awk -F: -v x="$1" '{print x":"$1}')
  else
      #echo $(xxd -pu -c 1000000 $1) > tmp_scr
      testo2=$(xxd -pu -c 1000000 $1)
      for ((i=0;i<$dimensione;i++))
      do
        testo2+="00"
      done
      #echo $testo2
      testo=$(grep -o -b  $2 <<< $testo2 | awk -F: -v x="$1" '{print x":"$1}')
  fi
  testo+=" "
  lista+=($testo)
}
 
# CONTROLLI

FILE=$(basename "$0")
lista=()

#CONTROLLA CHE LE OPZIONI PASSATE SIANO -r O -e
while getopts ":re:" opt
do
   if [[ $opt != "r" && $opt != "e" ]]
   then
       echo "Uso: $0 [opzioni] stringa file1...filen" >&2
       errore=1
       exit 10
   fi   
done 

# PRIMA ITERAZIONE NEGLI ARGOMENTI FINO 
# AD INCONTRARE UN PATH ESISTENTE PER RACCOGLIERE
# LE OPZIONI
opzione=0
x=0
presenza=0
z=1

for arg in $@
do
  if [ -e $arg ]
  then
      indice_file=$z
      z=$((z-1))
      indice_stringa=$z
      break
  elif [ $arg == "-r" ]
  then 
      presenza=1
      x=$((x+1))
      opzione=1
  elif [ $arg == "-e" ]
  then 
      indice_e=$z
      x=$((x+1))
      opzione=1
  fi
  z=$((z+1))
done
indice_e=$((indice_e+1))


# CONTROLLA CHE SE C'E' -r ALLORA CI DEVE ESSERE ANCHE -e
if [ $presenza -eq 1 -a $x -eq 1 ]
then 
    errore=1
    echo "Uso: $0 [opzioni] stringa file1...filen" >&2
    exit 10
fi


#CONTROLLA CHE CI SIANO IL NUMERO GIUSTO DI ARGOMENTI
if [ $x -eq 2 ]      # SIA -r CHE -e
then 
    if [ $# -lt 5 ]
    then
        errore=1
        echo "Uso: $0 [opzioni] stringa file1...filen" >&2
        exit 10
    fi
elif [ $x -eq 1 ]    # SOLO -e ( PERCHE SOLO -r E' IMPOSSIBILE)
then 
    if [ $# -lt 4 ]
    then
        errore=1
        echo "Uso: $0 [opzioni] stringa file1...filen" >&2
        exit 10
    fi   
elif [ $x -eq 0 ]   # NESSUNO DEI DUE
then     
    if [ $# -lt 2 ]
    then 
        errore=1
        echo "Uso: $0 [opzioni] stringa file1...filen" >&2
        exit 10
    fi
fi



# SECONDA ITERAZIONE NEGLI AROMENTI PER FORMARE
# LISTA_FILE, DIZIONARIO E DIZIONARIO NOMI
touch tmp  #output finale
touch tmp3 # file descriptor 3
touch tmp4 # file descriptor 4
touch tmp5 # file descriptor 5
contatore=0
lista_file=()        # LISTA DEI FILE DA CONSIDERARE PER L' ANALISI ( CON ANALIZZA())
dizionario=()        # DIZIONARIO CHE CONTA LE OCCORENZE DEGLI INODE
dizionario_nomi=()   # DIZIONARIO CHE TIENE INSIEME I NOMI DEI FILE CON LO STESSO INODE

for arg in ${@:$indice_file}
do
  if [ -h $arg ]
    then
        inode=$(ls -i $arg | awk '{print $1}')
        filename2=$(basename $arg)
        dizionario[$inode]=$((dizionario[$inode]+1))
        if [ ${dizionario[$inode]} -eq 1 ]
        then
            dizionario_nomi[$inode]+="$filename2"
        elif [ ${dizionario[$inode]} -gt 1 ]
        then
            dizionario_nomi[$inode]+="/$filename2"
        fi  
        puntato=$(ls -ld $arg | awk '{print $11}')
        puntato=$(basename "$puntato")
        lista_puntati+=($puntato)
        lista_file+=($arg)
    fi
  if [ -f $arg -a ! -h $arg ]
  then
      inode=$(ls -i $arg | awk '{print $1}')
      filename2=$(basename $arg)
      dizionario[$inode]=$((dizionario[$inode]+1))
      if [ ${dizionario[$inode]} -eq 1 ]
      then
          dizionario_nomi[$inode]+="$filename2"
      elif [ ${dizionario[$inode]} -gt 1 ]
      then
          dizionario_nomi[$inode]+="/$filename2"
      fi  
      lista_file+=($arg)
  elif [ ! -e $arg ]
  then
      contatore=$((contatore+1))
      #echo $arg >&2
      #echo $contatore >&2
      #echo "non esiste" >&2
      echo "L'argomento $arg non esiste" >> tmp3
  fi
  if [ -d $arg ] 
  then
      if [ $presenza -eq 1 ]
      then
          permessi=$(ls -ld $arg | awk '{print $1}')
          if [[ $permessi =~ .rw[xs]..[sS]... ]]
          then
              #echo $arg
              albero $arg ${!indice_e}
          else
              #echo $arg >&2
              contatore=$((contatore+1))
              #echo $contatore >&2
              #echo "non permessi" >&2
              permessi_ottale=$(stat -c '%a' $arg)
              echo "I permessi $permessi_ottale dell'argomento $arg non sono quelli richiesti" >> tmp5
          fi
      else
          #echo $arg >&2
          contatore=$((contatore+1))
          #echo $contatore >&2
          #echo "directory" >&2
          echo "L'argomento $arg e' una directory" >> tmp4
      fi
  fi
done

# for el in ${lista_file[@]}
# do
#   echo $el
# done
# echo ""

# ITERAZIONE IN LISTA_FILE 
for file in ${lista_file[@]}
do
  filename=$(basename "$file")
  trova $filename 
  if [ $trovato -ne 1 ]
  then
      inode=$(ls -i $file | awk '{print $1}')
      #echo dizionario[$inode]
      if [ ${dizionario[$inode]} -eq 1 ]
      then
          #echo $file
          analizza $file ${!indice_stringa}
      else
          stringa_nomi=$(tr "/" " " <<< ${dizionario_nomi[$inode]})
          min=$stringa_nomi
          #echo $stringa_nomi
          for el in $stringa_nomi
          do
            if [[ ${#el} -lt ${#min} ]]
            then
                min=$el
            fi
          done
          if [[ ${#filename} -eq ${#min} ]]
          then
              analizza $file ${!indice_stringa}
          fi
      fi
  fi
done
# output=""
# #echo ${lista[@]}
#echo ""
#echo ${lista[@]}
for elem in ${lista[@]}
do
  #echo $elem
  echo $elem >> tmp
  #cat tmp
  # if [ $elem != ${lista[-1]} ]
  # then
  #     elem+="\n"                # OCCHIOOOO CHE è QUESTO CHE FA ATTACCARE QUELLE DUE RIGHE
  # fi
  # output+=$elem
done


#echo -e $output > tmp
sort -r -u tmp >&1
# #cat tmp
sort -r -u tmp3 >&3
sort -r -u tmp4 >&4
sort -r -u tmp5 >&5

rm tmp    # finale output
rm tmp3 # file descriptor 3
rm tmp4 # file descriptor 4
rm tmp5 # file descriptor 5

ottale=$(printf %o $contatore)
echo $ottale >&2
exit $contatore

# # echo ${lista[@]}
# # output2=$(sort <<< $output)
# # echo -e $output2