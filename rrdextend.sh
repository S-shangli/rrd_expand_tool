#!/bin/zsh -f

################
# settings
extended_year=3      # extended value for "pdp_per_row" is 1
extended_month=0     # extended value for "pdp_per_row" is 1
extended_day=0       # extended value for "pdp_per_row" is 1
extended_hour=0      # extended value for "pdp_per_row" is 1
step_extend_num=1.5  # coefficient num for next "php_per_wor"
# end settings
################

# ex.
#   extended_year=3 month,day,hour=0
#   step_extend_num=1.5
# then
#   5mins   data : 3      years hold
#   30mins  data : 4.5    years hold
#   2hours  data : 6.75   years hold
#   24hours data : 10.125 years hold
#   (rrd step=300sec)

# ex.
#   extended_year=3 month,day,hour=0
#   step_extend_num=1
# then
#   all data spans : 3 years hold



### arg check
if [ $# -ne 1 ];
then
        echo "arg error : $0 <rrd_file>\n"
        exit 1
fi
if [ ! -e $1 ];
then
        echo "error : not found $1\n"
        exit 1
fi
FILE_RRD=$1


echo -n "backup ${FILE_RRD} to ${FILE_RRD}_bak \t ..."
cp -f "${FILE_RRD}" "${FILE_RRD}_bak"
if [ $? -eq 0 ];
then
        echo "ok"
else
        echo "err"
        exit 1
fi

echo -n "rrdtool resize ${FILE_RRD} \t ... "
step=`rrdtool info ${FILE_RRD} | grep 'step = ' | cut -d" " -f 3`
extended_rows=`echo "(${extended_year}*365*24*60*60 + \
                          ${extended_month}*31*24*60*60 + \
                          ${extended_day}*24*60*60      + \
                          ${extended_hour}*60*60           ) / ${step}" | bc`
err_cnt=0
for RRA_NUM in `rrdtool info ${FILE_RRD} | fgrep 'rra[' | cut -d'[' -f2 | cut -d']' -f1 | sort -u`
do
        now_rows=`rrdtool info ${FILE_RRD} | fgrep "rra[${RRA_NUM}].rows" | cut -d" " -f 3`
        now_pdp_per_row=`rrdtool info ${FILE_RRD} | fgrep "rra[${RRA_NUM}].pdp_per_row" | cut -d" " -f 3`
        if [ ${now_pdp_per_row} -eq 1 ];
        then
                step_extend=1
        else
                step_extend=`echo "scale=3;${step_extend} * ${step_extend_num}" | bc`
        fi

        grow_rows=`echo "scale=0;(${extended_rows} / ${now_pdp_per_row})*${step_extend} -  ${now_rows}" | bc | sed 's/\.[0-9]*$//g'`
        rrdtool resize ${FILE_RRD} ${RRA_NUM}.rows GROW ${grow_rows}
        err_cnt=`expr ${err_cnt} + $?`
        err_cnt=`expr ${err_cnt} + $?`
        \mv -f ./resize.rrd ${FILE_RRD}
done

if [ ${err_cnt} -eq 0 ];
then
        echo "ok"
else
        echo "err"
        exit 1
fi
