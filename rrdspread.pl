#!/bin/perl
use strict;
$|=1; # not bufferd

################
# settings
our $RRDTOOL="rrdtool";

# end settings
################





################
# arg check
if( @ARGV != 1    ){die "arg error:  $0 <rrd_file_name>\n"; }
if( ! -e $ARGV[0] ){die "error: notfound $ARGV[0]\n";     }
our $TARGET_RRDFILE=$ARGV[0];





################
# make dump file
print("rrdtool dump     : ${TARGET_RRDFILE} --> ${TARGET_RRDFILE}_xml ... ");
if( system("${RRDTOOL} dump ${TARGET_RRDFILE} ${TARGET_RRDFILE}_xml") ){
        die "\nerror: ${RRDTOOL} dump exit code error\n";
}
print("done\n");




################
# read dump file
print("read dumpfile    : ${TARGET_RRDFILE}_xml  ... ");
open(FH,"< ${TARGET_RRDFILE}_xml") or die("error: $!");
our @DUMPFILE=<FH>;
close(FH);
print("done\n");







################################################################################
# create valid DATA list
#
#$DATA{"CF_VALUE"}{"UTIME"}="<!-- 2014-10-14 09:00:00 JST / 1413244800 --> <row><v> 1.6369910800e+08 </v></row>"
#
#including all "UTIME" steps.
################################################################################
our %DATA;
our $OLDEND_UTIME=time();
our $NEWEND_UTIME=0;
our $STEP_UTIME=0;

print("data collectiong : ${TARGET_RRDFILE}_xml  ... ");


################
# search OLD,NEW,STEP_UTIME,CF_LIST
my @CF_LIST;
foreach my $DAT ( @DUMPFILE ){
        chomp($DAT);
        my $LINE=$DAT;
        if( $LINE =~ /<!-- [0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+ ... \/ [0-9]+ --> <row><v>.*<\/v><\/row>/ ){
            $LINE=~s/^.* \/ //g;
            $LINE=~s/ --> <row><v> .*//g;
            if( $OLDEND_UTIME > $LINE ){ $OLDEND_UTIME = $LINE; } # if found UTIME that to be old-end, set $OLDEND_UTIME
            if( $NEWEND_UTIME < $LINE ){ $NEWEND_UTIME = $LINE; } # if found UTIME that to be new-end, set $NEWEND_UTIME
        }elsif( $LINE =~ /<step>.*<\/step>/){
                $LINE=~s/^.*<step> //g;
                $LINE=~s/ <\/step>.*//g;
                $STEP_UTIME=$LINE;            # if found step, set $STEP_UTIME
        }elsif( $LINE =~ /<cf>.*<\/cf>/){
                $LINE=~s/^.*<cf>//g;
                $LINE=~s/<\/cf>.*//g;
                $LINE=~s/ //g;
                if( $CF_LIST[$#CF_LIST] ne $LINE ){push(@CF_LIST,$LINE);} # if found cf that are not recoded, add to CF_LIST
        }
}

################
# set %DATA initialvalue
for(my $i=$OLDEND_UTIME ; $i <= $NEWEND_UTIME ; $i+=$STEP_UTIME ){
        foreach my $cf_value ( @CF_LIST ){
                $DATA{"$cf_value"}{"$i"}="NaN";
        }
}
undef(@CF_LIST);

################
# get %DATA values
my $CF_VALUE="";
my $STEP=$STEP_UTIME;
foreach my $DAT ( @DUMPFILE ){
        chomp($DAT);
        my $LINE=$DAT;
        if( $LINE =~ /<cf>/){                     # find <cf> tag
                $LINE=~s/^.*<cf>//g;
                $LINE=~s/<\/cf>.*//g;
                $LINE=~s/ //g;
                $CF_VALUE=$LINE;
        }elsif( $LINE =~ /<pdp_per_row>.*<\/pdp_per_row>/ ){     # find <pdp_per_row> tag
                $LINE =~ s/^.*<pdp_per_row>//g;
                $LINE =~ s/<\/pdp_per_row>.*//g;
                $LINE =~s/ //g;
                $STEP = $LINE * $STEP_UTIME;
        }elsif( $LINE =~ /<!-- [0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+ ... \/ [0-9]+ --> <row><v>.*<\/v><\/row>/ &&
                        $LINE !~ /<v> NaN <\/v>/){               # find data line
                my $UTIME=$LINE;
                $UTIME=~s/^.* \/ //g;
                $UTIME=~s/ --> <row><v> .*//g;
                $LINE=~s/^.* --> //g;
                for( my $UTIME_VALUE=$UTIME ; $UTIME_VALUE < ($UTIME + $STEP) ; $UTIME_VALUE+=$STEP_UTIME){
                        if( $DATA{"$CF_VALUE"}{"$UTIME_VALUE"} eq "NaN" ){
                                $DATA{"$CF_VALUE"}{"$UTIME_VALUE"} =  $LINE;
                        }
                }
        }
}
undef($CF_VALUE);
print("done\n");









################################################################################
# OUTPUT DUMPFILE
print("spread & output  : ${TARGET_RRDFILE}_sprd ... ");
my $CF_VALUE="";
open(FH,"> ${TARGET_RRDFILE}_sprd") or die("error: $!");
foreach my $DAT ( @DUMPFILE ){
        chomp($DAT);
        my $LINE=$DAT;

        if( $LINE =~ /<cf>/){
                $CF_VALUE=$LINE;
                $CF_VALUE=~s/^.*<cf>//g;
                $CF_VALUE=~s/<\/cf>.*//g;
                $CF_VALUE=~s/ //g;
        }elsif( $LINE =~ /<!-- [0-9]+-[0-9]+-[0-9]+ [0-9]+:[0-9]+:[0-9]+ ... \/ [0-9]+ --> <row><v>.*<\/v><\/row>/ &&
                        $LINE =~ /<v> NaN <\/v>/){             # find data line
                my $UTIME_VALUE=$LINE;
                $UTIME_VALUE=~ s/^.* \/ //g;
                $UTIME_VALUE=~ s/ --> <row><v> .*//g;
                $UTIME_VALUE=~ s/ //g;
                if( $DATA{"$CF_VALUE"}{"$UTIME_VALUE"} ne "NaN" ){
                        $LINE=~ s/--> <row><v> .*/--> /g;
                        print FH $LINE.$DATA{"$CF_VALUE"}{"$UTIME_VALUE"}."\n";
                }else{
                        print FH $DAT."\n";
                }
                next;
        }

        print FH $DAT."\n";
}
close(FH);
undef($CF_VALUE);
print("done\n");






################
# create rrd
print("rrdtool restore  : ${TARGET_RRDFILE}_sprd --> ${TARGET_RRDFILE}_new ... ");
if( system("${RRDTOOL} restore ${TARGET_RRDFILE}_sprd ${TARGET_RRDFILE}_new") ){
        die "\nerror: ${RRDTOOL} restore exit code error\n";
}
print("done\n");

print("rrd file backup  : ${TARGET_RRDFILE}      --> ${TARGET_RRDFILE}_BAK ... ");
if( system("\\mv -f ${TARGET_RRDFILE} ${TARGET_RRDFILE}_BAK") ){
        die "\nerror: mv -f ${TARGET_RRDFILE} ${TARGET_RRDFILE}_BAK exit code error\n";
}
print("done\n");

print("rrd file swap    : ${TARGET_RRDFILE}_new  --> ${TARGET_RRDFILE}     ... ");
if( system("\\mv -f ${TARGET_RRDFILE}_new ${TARGET_RRDFILE}") ){
        die "\nerror: mv -f ${TARGET_RRDFILE}_new ${TARGET_RRDFILE} exit code error\n";
}
print("done\n");




################
# delete temp files
print("delete temporary : ${TARGET_RRDFILE}_xml  ... ");
if( system("\\rm -f ${TARGET_RRDFILE}_xml") ){
        die "\nerror: rm -f ${TARGET_RRDFILE}_xml exit code error\n";
}
print("done\n");

print("delete temporary : ${TARGET_RRDFILE}_sprd ... ");
if( system("\\rm -f  ${TARGET_RRDFILE}_sprd") ){
        die "\nerror: rm -f  ${TARGET_RRDFILE}_sprd exit code error\n";
}
print("done\n");
