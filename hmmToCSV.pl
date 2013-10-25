#Author: Eric Spaulding

use strict; #enforce strict mode
use warnings; #give warnings

$| = 1; ##dumps print lines as you go rather than saving up the buffer
binmode STDOUT, ":utf8"; ##alows for the use of some unicode characters
use constant { true => 1, false => 0 }; #define true and false for the rest of the script
my $os = $^O; #get the current operating system that the script is being run under
#os results that I've seen
#windows8 -> MSWin32
#linux mint14 -> linux
#juno -> linux
#cygwin use bash from cmd -> MSWin32 (in other words it reports the native windows os)
#cygwin terminal -> cygwin

#print "running in: $os\n";
#exit;

#regex option characters
    # s -> cause the . character to also match the newline character
    # m -> multiline mode cause ^ and $ to match the beginning and end of each 
    #      line rather than the beginning and end of the input string
    # i -> ignore case when matching
    # g -> match globally, i.e. continue until all matches are found one by one
####################################### REGEX DEFINITIONS ####################
my $state_char = '[A-Za-z]+[0-9]*'; #always 1 or more alpha characters optionally followed by numbers
my $emit_char = '[A-Za-z]+'; #1 or more alphabet characters, no numbers allowed
my $probability = '0?\.?[0-9]*'; #zero or more numbers, optionally preceeded by 0. or . or 0
my $number = '-?[0-9]+'; #possibly negative integer number with no decimal places allowed
my $structure_name = '[A-Za-z0-9-\s]*$'; #allow letters, numbers, -, and whitespace
                                                                                 #options
my $state_character_definition_block = "#state character definition(.*)#end scd";#ism
my $state_character_syntax = "^($state_char)\\|(.*)\$";                          #mg
my $emissions_syntax = "^($probability)->($emit_char)\\s*\$";                    #

my $model_structure_definition_block = '#model structures(.*)#end model';        #ism
my $model_syntax = "^>($number)\\|($structure_name)(.*?)#";                      #smg
my $state_syntax = "^($number)\\|($state_char)\\|(.*)\$";                        #
my $transition_syntax = "^($probability)->($number)\\s*\$";                      #

#wrap all the main code in a function in order to keep the global namespace clean
sub main{
	my $trans = "TRANS.csv";
    my $emit  = "EMIT.csv";
	my $file = "sample.hmm"; #default script that we'll look for and process
    my $scriptname = $0; #the name of this script
    my $total = $#ARGV + 1;

    if ($total == 1){ #assume the user gave us a .hmm file to process
        $file = $ARGV[0];
    }
	
    #collect data for the transition matrix and emission matrix
	my $model = buildModel({ data => readfile({filename => $file}) });
	
	#write the trans data to a csv file
	writeCSV({filename   => $trans,
              matrix     => $model->{'TRANS'},
		      delimiter  => ","});

    #write the emit data to a csv file
    writeCSV({filename   => $emit,
              matrix     => $model->{'EMIT'},
              delimiter  => ","});
}

#Build the transition and emission matrix
sub buildModel{
    
    my $args = shift;
    my $data = $args->{'data'};
    my $bigString = join("",@$data);

    my %statechars; #{statechar}{emitchar} = probability
    my %emitchars;  #distinct list of possible emissions from any state
                    #each of these becomes a column in the emission matrix
    #determine acceptable state characters and their emissions
    if($bigString =~ /$state_character_definition_block/ism){
        defineStateCharacters({emitchars  => \%emitchars,
                               statechars => \%statechars,
                               text       => stripComments({text          => $1,
                                                            comment_start => '\/\/'}) 
                             });
    } else {
        die "state character definition section not found.\n";
    }

    my %structures; my $numstates = 0;
    #build the transition model
    if($bigString =~ /$model_structure_definition_block/ism){                    
        $numstates = buildTransitionModel({statechars => \%statechars,
                                           structures => \%structures,
                                           text       => stripComments({text          => $1,
                                                                        comment_start => '\/\/'}) 
                                         });
    } else {
        die "model structures section not found\n";
    }

    my @emission;   # [row][column] with row==state_from, column[c]==probability(emitchars[c])
    my @transition; # [row][column] with row==state_from, column[c]==probability(state_to)
    my $row = 0;

    #build transition and emission matrix
    my @structkeys = getNumericSortKeys(%structures);
    my %statecounts = ();
    foreach my $sk (@structkeys){
        my @statekeys = getNumericSortKeys(%{$structures{$sk}->{'states'}});
        my $num = @statekeys;
        foreach my $statekey (@statekeys){
            my @erow = (0) x (keys %emitchars);
            my @trow = (0) x $numstates;
            push(@transition, \@trow); #push an array prefilled with zeroes for the transition row
            my $trans = $structures{$sk}->{'states'}->{$statekey}->{'trans'};
            foreach (@$trans){
                $transition[$row]->[$_->{'dest'}-1] = $_->{'prob'};
            }
            push(@emission, \@erow);   #push an array prefilled with zeroes for the emission row
            my $char = $structures{$sk}->{'states'}->{$statekey}->{'char'};
            foreach my $e (keys %{$statechars{$char}}){
                $emission[$row]->[$emitchars{$e}] = $statechars{$char}{$e};
            }
            $row += 1;
        }
    }
    
    my %model = ('TRANS', \@transition, 'EMIT', \@emission);
    return \%model;
}

#definition of the %structures datatype
#(structnum => {name    => string,
#               states  => {statenum => {char  => string,
#                                        trans => [{dest => int,
#                                                   prob => decimal
#                                                 }]
#                                       }
#                          }
#              }
#)
#example of retrieving name model structure maybe these could be row headers in csv
# with the right options enabled
#my $structname    = $structures{1}->{'name'};

#example of retrieving the state character of a state
#my $statechar = $structures{1}->{'states'}->{1}->{'char'};

#example of retrieving a transition probability and destination of a state
#my $prob = $structures{1}->{'states'}->{1}->{'trans'}->[0]->{'prob'};
#my $dest = $structures{1}->{'states'}->{1}->{'trans'}->[0]->{'dest'};
sub buildTransitionModel{
    my $args = shift;
    my $statechars = $args->{'statechars'};
    my $structures = $args->{'structures'};

    #process the model structures one by one
    while($args->{'text'} =~ /$model_syntax/smg){
        my %states = (); my $name = $2;
        my %struct = ('name',$name,'states',\%states);
        $structures->{$1} = \%struct;

        #process each state for this internal structure of the model
        my @structStates = split(/\n/,$3);
        foreach my $s (@structStates){
            if(length($s) == 0) { next; } #caught a blank line skip to next
            if($s =~ /$state_syntax/){
                my $state_num = $1;
                if(!exists($statechars->{$2})){ #make sure the state character is defined
                    die "Undefined state character used in structure \"$name\"\n";
                }
                if(exists($states{$state_num})){ #check if more than 1 state has the same number
                    die "More than one state has the same number in structure \"$name\"\n";
                }
                my @trans; #each entry here will become a non-zero entry in the transition csv
                my %state = ('char',$2,'trans',\@trans);
                $states{$state_num} = \%state;
                my @transitions = split(/;/,$3); my $sum = 0;
                foreach (@transitions){ #process the transitions for this state
                    if($_ =~ /$transition_syntax/){
                        push(@trans,{dest => $2,prob => $1});
                        $sum += $1;
                    } else{
                        print "$_\n";
                        die "Invalid syntax in structure \"$name\", state $state_num\n";
                    }
                }
                if($sum != 1){ #check if all the transitions sum to 1 for this state
                    die "error the transitions for structure \"$name\", state #$state_num sum to $sum instead of 1\n";
                }           
            } else {
                die "Invalid state syntax in structure \"$name\", $s\n";
            }
        } #end for that processes model structure states
    } #end while that processes model structures

    #update model states to global state numbers in the specified structure order
    my @structkeys = getNumericSortKeys(%$structures);
    my $gsc = 0; #global state count
    my ($maxname, $maxstate, $max) = ("",0,-1);
    my ($minname, $minstate, $min) = ("",0,999999);
    foreach my $sk (@structkeys){
        my @statekeys = getNumericSortKeys(%{$structures->{$sk}->{'states'}});
        my $num = @statekeys;
        foreach my $statekey (@statekeys){
            my $trans = $structures->{$sk}->{'states'}->{$statekey}->{'trans'};
            foreach (@$trans){
                $_->{'dest'} += $gsc; #adjust for earlier structures in the model
                if ($_->{'dest'} > $max){ #keep track of the highest destination state
                    $max = $_->{'dest'}; $maxstate = $statekey; $maxname = $structures->{$sk}->{'name'};
                } 
                if ($_->{'dest'} < $min){ #keep track of the lowest destination state
                    $min = $_->{'dest'}; $minstate = $statekey; $minname = $structures->{$sk}->{'name'};
                } 
            }
        }
        $gsc += $num;
    }

    #make sure destination states really exist
    my $error = "Out of states 1 to $gsc\nThere is an invalid destination of ";
    if($max > $gsc) {
        die "$error($max) in structure \"$maxname\" at state #$maxstate\n";
    }
    if($min < 1) {
        die "$error($min) in structure \"$minname\" at state #$minstate\n";
    }
    return $gsc;
}

#process state character definition section
sub defineStateCharacters{
    my $args = shift;
    my $emitchars  = $args->{'emitchars'};
    my $statechars = $args->{'statechars'};

    while($args->{'text'} =~ /$state_character_syntax/mg){
        my $char = $1;
        if(exists($statechars->{$char})){ #make sure the state character isn't already defined
            die "The state character $char is defined more than once\n";
        }
        my @emits = split(/;/,$2); my $sum = 0;
        foreach (@emits){ #process each emission for this state character being defined
            if($_ =~ /$emissions_syntax/){
                $emitchars->{$2} = 0;
                $statechars->{$char}{$2} = $1; #{statechar}{emitchar} = probability
                $sum += $1;
            } else {
                die "syntax error in the definition of state character $char\n";
            }
        }
        if($sum != 1){ #make sure all the emissions for this state character sum to 1
            die "error the emissions for state character $char sum to $sum instead of 1\n";
        }
    }

    #set the column index for each emission character starting with 0
    my $count = 0;
    my @emitlist = keys %{$emitchars};
    foreach (@emitlist){
        $emitchars->{$_} = $count;
        $count += 1;
    }
}

#assume that 2d array (matrix) is in row major format
#and write it to the specified file
sub writeCSV{
	my $args = shift;
    my $filename = $args->{'filename'};
    my @matrix = @{$args->{'matrix'}};

    print "\nwriting data to $filename... ";
    open(OUT,">$filename")||die;

    #print the 2d array into a file
    foreach my $row (@matrix){
        #print all the elements(columns) of this row joined by commas
        print OUT join($args->{'delimiter'},@{$row});
        print OUT "\n";
    }
    close(OUT);
    print "Done.\n";
}

#read a file and put the query sequences into memory
sub readfile{
    my $args = shift;
    my $filename = $args->{'filename'};

    #Open the file
    print "opening data from $args->{'filename'}\n";
    open(IN,$filename)||die "$filename not found"; 
    
    my @lines = <IN>;  #read in all of the lines at once, so the lines are stored in an array
    close(IN);         #close the file
    
    return \@lines;
}

sub stripComments{
    my $args = shift;
    my $regex = $args->{'comment_start'}.'.*$';
    my $text = $args->{'text'};
    $text =~ s/$regex//mg;
    return $text;
}

#return a new array with only 1 of each unique element found in the original array
sub distinct{
    my @list = @_;
    my %seen; @seen{@list} = ();
    my @uniquelist = (keys %seen);
    return @uniquelist;
}

#given a hash return the keys sorted numerically
sub getNumericSortKeys{
    my %hash = @_;
    return (sort {$a<=>$b} keys %hash);
}

main();