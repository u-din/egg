#  If you are not a Server Administrator or higher on an IRC Network that runs Unreal IRCd   #
#  or Ultimate IRCd, then you can't use this script unless there are other IRCd's that use   #
#  the same commands.                                                                        #
#                                                                                            #
#  The bot *MUST* be an IRCOp with the ability to use the "/chghost" command.                #
#                                                                                            #
#                                                                                            #
#                                                                                            #

# Set this to the Command Character of you're choice (default is !) #
set PUBCMD "!"

bind msg -|- vhost msg:vhost
bind msg n oper oper-up
bind pub -|- ${PUBCMD}vhost pub:vhost
bind pub -|- ${PUBCMD}randomvhost pub:ranvhost
bind join -|- *!*@* join:ran
bind msg -|- random msg:ran
bind msg -|- addvhost msg:addvhost
bind bot -|- auto-oper auto-oper

# Set this to the channel you want your bot to give out VHost's from #
set vhostchan "#chat"

# Set this to your eggdrop's nickname. #
set botnickname "$botnick"

# Set this to your eggdrop's alt nick. #
set botaltnick "v"

# Change this to your nickname #
set owner2 "isfan"

# Set this to be how long (in minutes) you want to ban/ignore a user after they get a vhost. #
set bntime "30"

# Enable or disable public commands here. (on / off) #
  # !randomvhost #
set pub_randomvhost "on"
  # !vhost #
set pub_vhost "on"
  # /msg bot vhost vhost.here #
set msg_vhost "on"
  # /msg bot random #
set msg_random "off"


# Set this to the nicknames you want to allow to add new VHosts to the bot's list. (separate with a space) #
set vhostnicks "$owner2"

# Alternatively (and more securely) you can set a flag that users must have in order to add vhosts. #
set add_vhost_flag "V"

# Set the type of authentication you want to use for people to add VHosts. (flag / nicks) #
set av_type "flag"


# Set this to the bot's O-Line username #
set operid "vhost"

# Set this to the bots O-Line password #
set operpass "123"

# Set this to the nicknames you want exempt from getting vhosts when they join the VHost channel. (separate with a space) #
set exemptnicks "$owner2 $botnick $botaltnick"

proc oper-up {nick host chan text} {
  global operid operpass owner2
  putserv "OPER $operid $operpass"
  putserv "NOTICE $owner2 :I Opered up"
}
set vhost_masktype 2
proc msg:vhost {nick uhost hand vhost} {
  global bntime msg_vhost
  if {$msg_vhost == "on"} {
  set vhost [lindex $vhost 0]
  set fullvhost "*!*[string range $uhost [string first ! $uhost] 4]*@[string range $vhost [string first @ $vhost] end]"
  set ihost [vhost:masktype $uhost]
  putserv "CHGHOST $nick $vhost"
  putserv "NOTICE $nick : Your Vhost has been changed to: $vhost"
  putserv "NOTICE $nick : You may only have one vhost change per $bntime minutes."
  newignore $ihost VHost $nick $bntime
  newignore $fullvhost VHost $nick $bntime
  } else {
  putserv "PRIVMSG $nick :The msg vhost command has been turned off."
  }
}

proc auto-oper {} {
  global operid operpass botnick vhostchan
  putquick "OPER $operid $operpass"
  putserv "SAMODE $vhostchan +o $botnick"
}

proc join:ran {nick host hand chan} {
  global ison operid operpass botnick vhostchan exemptnicks bntime
  set joinvhost "[get_vhost]"
  set realbhost [vhost:masktype $host]
  if {$chan == "[lindex $vhostchan 0]" && ([lsearch -exact [string tolower $exemptnicks] [string tolower $nick]] == -1)} {
  putquick "CHGHOST $nick $joinvhost"
  putserv "MODE $vhostchan +b $realbhost"
  putserv "MODE $vhostchan +b *!*@$joinvhost"
  putserv "MODE $vhostchan +b $realbhost"
  puthelp "KICK $vhostchan $nick one vhost change per $bntime minutes."
  puthelp "NOTICE $nick :Your new VHost is: $joinvhost"
  puthelp "NOTICE $nick :You may only have one vhost change per $bntime minutes."
  timer $bntime "pushmode $vhostchan -b *!*@$joinvhost"
  timer $bntime "pushmode $vhostchan -b $realbhost"
  }
  if {$chan == "[lindex $vhostchan 0]" && ($nick == $botnick)} {
  timer 1 "auto-oper"
  }
}

proc vhost:masktype {uhost} {
  global vhost_masktype
  switch -exact -- $vhost_masktype {
    0 {return *!*[string range $uhost [string first @ $uhost] end]}
    1 {return *!*$uhost}
    2 {return *!*[lindex [split [maskhost $uhost] "!"] 1]}
  }
  return
}

proc msg:ran {nick uhost hand read} {
  global bntime msg_random 
  if {$msg_random == "on"} {
  set ranvhost "[get_vhost]"
  set fullvhost "*!*[string range $uhost [string first ! $uhost] 4]*@[string range $ranvhost [string first @ $ranvhost] end]"
  set ihost [vhost:masktype $uhost]
  putserv "CHGHOST $nick $ranvhost"
  putserv "NOTICE $nick :Your new VHost is: $ranvhost"
  putserv "NOTICE $nick :You may only have one vhost change per $bntime minutes."
  newignore $ihost VHost $nick $bntime
  newignore $fullvhost VHost $nick $bntime
  } else {
  putserv "PRIVMSG $nick :The msg random command has been turned off."
  }
}

proc pub:vhost {nick uhost hand chan text} {
  global bntime pub_vhost PUBCMD
  if {$pub_vhost == "on"} {
  set vhost [lindex $text 0]
  set fullvhost "*!*[string range $uhost [string first ! $uhost] 4]*@[string range $vhost [string first @ $vhost] end]"
  set ihost [vhost:masktype $uhost]
  putserv "CHGHOST $nick $vhost"
  putserv "NOTICE $nick :Your new VHost is: $vhost"
  putserv "NOTICE $nick :You may only have one vhost change per $bntime minutes."
  newignore $ihost VHost $nick $bntime
  newignore $fullvhost VHost $nick $bntime
  } else {
  putserv "NOTICE $nick :The ${PUBCMD}vhost command has been turned off."
  }
}
proc pub:ranvhost {nick uhost hand chan text} {
  global bntime pub_randomvhost PUBCMD
  if {$pub_randomvhost == "on"} {
  set ranvhost "[get_vhost]"
  set fullvhost "*!*[string range $uhost [string first ! $uhost] 4]*@[string range $ranvhost [string first @ $ranvhost] end]"
  set ihost [vhost:masktype $uhost]
  putserv "CHGHOST $nick $ranvhost"
  putserv "NOTICE $nick :Your new VHost is: $ranvhost"
  putserv "NOTICE $nick :You may only have one vhost change per $bntime minutes."
  newignore $ihost VHost $nick $bntime
  newignore $fullvhost VHost $nick $bntime
  } else {
  putserv "NOTICE $nick :The ${PUBCMD}random command has been turned off."
  }
}

proc get_vhost { } {
  set f [open "VHostlist.txt" r]
  set vhostcount 0
  while {[gets $f line] != -1} {
    incr vhostcount
  }
  close $f
  set vhostcount [expr $vhostcount -1]

  set vhostnum [rand $vhostcount]

  set f [open "VHostlist.txt" r]
  set vnum 0
  while {$vnum <= $vhostcount} {
    gets $f line
    incr vnum
    set vhnum [expr $vnum -1]
    if {$vhnum == $vhostnum} {
      set vhost "[lrange $line 0 end]"
      if {$vhost == ""} {
        set vhostnum [rand $vhostcount]
        set vnum 0
      }
    }
  }
  return $vhost
}

proc msg:addvhost { nick host hand arg } {
global av_type add_vhost_flag vhostnicks

set allowed "0"
if {$av_type == "flag"} {
  if {[matchattr $hand $add_vhost_flag]} {
    set allowed "1"
  }
} elseif {$av_type == "nicks"} {
  if {([lsearch -exact [string tolower $vhostnicks] [string tolower $nick]] != -1)} {
    set allowed "1"
  }
} else {
  set allowed "0"
}

if {$allowed == "1"} {

    set newvhost "$arg"
    set f [open "VHostlist.txt" r]
    set tmpf [open "VHostlist.txt.tmp" w]

    while {[gets $f line] != -1} {
      puts $tmpf "$line"
    }

    puts $tmpf "$newvhost"
    putserv "PRIVMSG $nick :The new VHost: \"$newvhost\" has been added to the list."

    close $f
    close $tmpf

    set f [open "VHostlist.txt.tmp" r]
    set vhostdb "[read $f]"
    close $f
    set f [open "VHostlist.txt" w]
    puts $f "$vhostdb"
    close $f
    return 0
  } else {
    putserv "PRIVMSG $nick :You do not appear to be allowed to add vhosts to this bot.."
  }
}

putlog "\002(1: \0039VHOST\003)\002 Loaded: \002VHOST\002"
putlog "\002(1: \0039VHOST\003)\002 From The Chating-IRC Network -- \002http://www.chating.id\002"
