# rrd_expand_tool
tools of expand and spread the rrd database.

## assumed usecases
I wanted more long time datas for Cacti.
But Cacti did not support the extension of the **existing** rrd file.

## Problems to be solved
1. expand existing rrd database file
2. copy data values to new area that are expanded
   + because, Cacti(rrdtool) tries to refer to more detailed data, even if coarse data exists in a newly expanded area, it is judged that there is no data.

## software requirements
- zsh
- perl
- rrdtool
- bc, grep, cut, sort, mv

## usage
    [prompt]$ ./rrdextend.sh HOGEHOGE.rrd
    rrdtool resize ./HOGEHOGE.rrd	 ... ok
    
    [prompt]$ ./rrdspread.pl HOGEHOGE.rrd
    rrdtool dump     : ./HOGEHOGE.rrd --> ./HOGEHOGE.rrd_xml ... done
    read dumpfile    : ./HOGEHOGE.rrd_xml  ... done
    data collectiong : ./HOGEHOGE.rrd_xml  ... done
    spread & output  : ./HOGEHOGE.rrd_sprd ... done
    rrdtool restore  : ./HOGEHOGE.rrd_sprd --> ./HOGEHOGE.rrd_new ... done
    rrd file backup  : ./HOGEHOGE.rrd      --> ./HOGEHOGE.rrd_BAK ... done
    rrd file swap    : ./HOGEHOGE.rrd_new  --> ./HOGEHOGE.rrd     ... done
    delete temporary : ./HOGEHOGE.rrd_xml  ... done
    delete temporary : ./HOGEHOGE.rrd_sprd ... done

## rrdextend.sh
expand existing rrd database file
- settings(in file)
    - extended_year, extended_month, extended_day, extended_hour  
    **set the extended dates you want.**
    - step_extend_num  
    **coefficient num for next rough datas**
- for example
    - extended_year=3, month,day,hour=0 and step_extend_num=1.5  
    **5mins   data : 3      years hold**  
    **30mins  data : 4.5    years hold**  
    **2hours  data : 6.75   years hold**  
    **24hours data : 10.125 years hold**  
    **(rrd step=300sec)**  

## rrdspread.pl
copy data values to new area that are expanded
- settings(in file)
   - our $RRDTOOL="rrdtool";  
   **path of rrdtool command**  

## expand & spread image
    
                      time axis  old -----------------> latest
    before expand:
    5min data : [ CCC ] [ BBB ] [ AAA ]
    10min data: [ CC' ] [ BB' ] [ AA' ]
    30min data: [ C'' ] [ B'' ] [ A'' ]
    
    after expand:
    5min data : [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ CCC ] [ BBB ] [ AAA ]
    10min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ CC' ] [ BB' ] [ AA' ]
    30min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ C'' ] [ B'' ] [ A'' ]
    
    before spread:
    5min data : [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ CCC ] [ BBB ] [ AAA ]
    10min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ CC' ] [ BB' ] [ AA' ]
    30min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ C'' ] [ B'' ] [ A'' ]
    
    after spread:
    5min data : [ B'' ] [ B'' ] [ CC' ] [ CC' ] [ BB' ] [ CCC ] [ BBB ] [ AAA ]
    10min data: [ C'' ] [ C'' ] [ B'' ] [ B'' ] [ B'' ] [ CC' ] [ BB' ] [ AA' ]
    30min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ C'' ] [ B'' ] [ A'' ]
    
    spread images:
    5min data : [ B'' ] [ B'' ] [ CC' ] [ CC' ] [ BB' ] [ CCC ] [ BBB ] [ AAA ]
                   |       |       |       |       |
                   |       |       |       |       +--------------+
                   |       |       |       |                      |
                   |       |       +-------+---------------+      |
                   |       |                               |      |
                   +-------+-----------------------+       |      |
                                                   |       |      |
    10min data: [ C'' ] [ C'' ] [ B'' ] [ B'' ] [ B'' ] [ CC' ] [ BB' ] [ AA' ]
                   |       |       |       |       |
                   |       |       +-------+-------+--------------+
                   |       |                                      |
                   +-------+-------------------------------+      |
                                                           |      |
    30min data: [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ NaN ] [ C'' ] [ B'' ] [ A'' ]


