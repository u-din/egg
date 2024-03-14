# Google news v0.3 by nrt (01Dec2015)
# Updated GoogleNews Country links and added some more lines for redirected link support (04Jan2018) karakedi

package require tdom
package require http
package require htmlparse
package require textutil::split
package require tls 1.6.4
package present Tcl 8.6

set ::oldnews [list ]

set googlelink {https://news.google.com/news/rss/headlines/section/topic/NATION}

# Length of chars in a line.
set newsmax 412

# Links shortened to tinyurl. 1 = true , 0 = false
set tinyurl 0

# 1 = US_en (U.S.A), 2 = TR (Turkey) , 3 = FR (France), 4 = DE (Germany), 5 = UK_en (U.K) , 6 = RU (Russia)
# 7 = IT (Italy) , 8 = NL (Netherlands) , 9 = AU_en (Australia) , 10 = PT (Portugal) , 11 = AR (Arabian World) , 12 = AT_de (Austria)
# 13 = BE_fr (Belgium) , 14 = BR_pt (Brazil) , 15 = BG (Bulgaria) , 16 = CA_en (Canada) , 17 = NZ_en (New Zealand) , 18 = PL (Poland)
# 19 = RO (Romania) , 20 = CS (Czech Republic) , 21 = NO (Norway) , 22 = CH_fr (Switzerland) , 23 = SV (Sweden) , 24 = SR (Serbia)
# 25 = CN_zh (China) , 26 = JA (Japan) , 27 = GR (Greece) , 28 = LT (Lithuania) , 29 = IN_en (India) , 30 = HU (Hungary)
# 31 = AR (Argentina) , 32 = ID (Indonesia) , 33 = MY (Malaysia) , 34 = BN (Bangladesh) , 35 = MX (Mexico) , 36 = PK_en (Pakistan)
# news in this language/nation
set newslang 32

# This is for set a limit, do not post if that headline older than ** minutes
set headlinedelay 20

# .news on <- to enable on your #channel / .news off <- for turn this off!
setudef flag googlenews

bind pub mnf|oa ".news" news_control
bind evnt - init-server news_refresh

if {[package vcompare [package present tls] 1.7] > 0} {
	::http::register https 443 [list ::tls::socket -autoservername 1]
} else {
	::http::register https 443 [list ::tls::socket -request 0 -require 1 -ssl2 0 -ssl3 0 -tls1 1]
}

proc langSel {} {
	switch -exact -- $::newslang {
		1 { set url {us&hl=en&gl=US} }
		2 { set url {tr_tr&hl=tr&gl=TR} }
		3 { set url {fr&hl=fr&gl=FR} }
		4 { set url {de&hl=de&gl=DE} }
		5 { set url {uk&hl=en-GB&gl=GB} }
		6 { set url {ru_ru&hl=ru&gl=RU} }
		7 { set url {it&hl=it&gl=IT} }
		8 { set url {nl_nl&hl=nl&gl=NL} }
		9 { set url {au&hl=en-AU&gl=AU} }
		10 { set url {pt-PT_pt&hl=pt-PT&gl=PT} }
		11 { set url {ar_me&hl=ar&gl=ME} }
		12 { set url {de_at&hl=de-AT&gl=AT} }
		13 { set url {fr_be&hl=fr&gl=BE} }
		14 { set url {pt-BR_br&hl=pt-BR&gl=BR} }
		15 { set url {bg_bg&hl=bg&gl=BG} }
		16 { set url {ca&hl=en-CA&gl=CA} }
		17 { set url {nz&hl=en-NZ&gl=NZ} }
		18 { set url {pl_pl&hl=pl&gl=PL} }
		19 { set url {ro_ro&hl=ro&gl=RO} }
		20 { set url {cs_cz&hl=cs&gl=CZ} }
		21 { set url {no_no&hl=no&gl=NO} }
		22 { set url {fr_ch&hl=fr-CH&gl=CH} }
		23 { set url {sv_se&hl=sv&gl=SE} }
		24 { set url {sr_rs&hl=sr&gl=RS} }
		25 { set url {cn&hl=zh-CN&gl=CN} }
		26 { set url {jp&hl=ja&gl=JP} }
		27 { set url {el_gr&hl=el&gl=GR} }
		28 { set url {lt_lt&hl=lt&gl=LT} }
		29 { set url {in&hl=en-IN&gl=IN} }
		30 { set url {hu_hu&hl=hu&gl=HU} }
		31 { set url {es_ar&hl=es-419&gl=AR} }
		32 { set url {id_id&hl=id&gl=ID} }
		33 { set url {en_my&hl=en-MY&gl=MY} }
		34 { set url {bn_bd&hl=bn&gl=BD} }
		35 { set url {es_mx&hl=es-419&gl=MX} }
		36 { set url {en_pk&hl=en&gl=PK} }
		default { set url {us&hl=en&gl=US} }
	}
	return ${::googlelink}?ned=$url
}

proc news_refresh {type} {
	foreach chan [channels] newsbind [binds time] {
		if {([lsearch -exact [channel info $chan] "+googlenews"] != "-1")\
				&& ![string match "*Google:News*" $newsbind]} {
			bind time - "*" Google:News
			return 1
		}
	}
}

proc news_control {nick uhost hand chan text} {
	switch -nocase -- [lindex [split $text] 0] {
		"on" { if {[channel get $chan googlenews]} {
				puthelp "privmsg $chan :News already running @ $chan"
			} {
				bind time - "*" Google:News
				channel set $chan +googlenews
				puthelp "privmsg $chan :News now enabled @ $chan"
			}
		}
		"off" { if {![channel get $chan googlenews]} {
				puthelp "privmsg $chan :News already disabled @ $chan"
			} {
				unbind time - "*" Google:News
				channel set $chan -googlenews
				puthelp "privmsg $chan :News now stopped @ $chan"
			}
		}
		default { puthelp "privmsg $chan :Usage: $::lastbind <on/off>" }
	}
	return 0
}

proc getit {url} {
	if {[catch {set token [http::geturl $url -binary 1 -timeout 15000]} error]} {
		putcmdlog "[string map [list \n " "] $error]"
		return 0
	} elseif {[http::status $token] eq "ok" && [http::ncode $token] == "200"} {
		set data [http::data $token]
		::http::cleanup $token
	} elseif {[string match *[http::ncode $token]* "307|303|302|301"]} {
		upvar #0 $token state
		foreach {names values} $state(meta) {
			if {[regexp -- {^Location$} $names]} {
				putlog "Redirecting to $values"
				::http::cleanup $token
				if {[catch {set tok [http::geturl $values -binary 1 -timeout 15000]} err]} {
					putcmdlog "[string map [list \n " "] $err]"
					break
				} elseif {[http::status $tok] eq "ok" && [http::ncode $tok] == "200"} {
					set data [http::data $tok]
					::http::cleanup $tok
				} else {
					putcmdlog "[http::status $tok] - [http::code $tok]"
					::http::cleanup $tok
				}
			}
		}
	} else {
		putcmdlog "[http::status $token] - [http::code $token]"
		::http::cleanup $token
	}
	if {[info exists data]} {
		return [encoding convertfrom utf-8 $data]
	}
}

proc newsdom {} {
	set document [dom parse [getit [langSel]]]
	set root [$document documentElement]
	foreach id [$root selectNodes "/rss/channel/item"] {
		set description [[$id selectNodes "description"] text]
		set pubDate [[$id selectNodes "pubDate"] text]
		set newsurl [[$id selectNodes "link"] text]
		lappend news "[dom_trim $description] | [dom_trim $newsurl] | [clock scan [dom_trim $pubDate]]"
	}
	$document delete
	set listnews [lindex [lsort -integer -decreasing -index end $news] 0]
	return [join [htmlparse::mapEscapes $listnews]]
}

proc news_print {where what} {
	regexp {^(.*?)(http(?:s|)://[^\s]+)(.*?)$} $what - res links _
	set output [textutil::split::splitn $what $::newsmax]
	if {[string match *${links}* $output]} {
		lmap newsout $output { puthelp "privmsg $where :$newsout" }
	} else {
		lmap newsout [textutil::split::splitn $what [string length $res]] { puthelp "privmsg $where :$newsout" }
	}
}

proc dom_trim {str} {
	regsub -all -nocase {(?:<strong>|</strong>|<b>|</b>)} $str "\002" str
	regsub -all -- {<font color="#6f6f6f">(.*?)</font>} $str "(\00304\\1\003)" str
	set str [string map [list &lt\; \u003c &gt\; \u003e &nbsp\; \u0020 \" \u0027] $str]
	regsub -all -- "<.+?>" $str { } str
	regsub -all -- {\s+} $str "\u0020" str
	return [string trim $str]
}

proc news_tiny {link} {
	set tinyurl [getit http://tinyurl.com/api-create.php?[http::formatQuery url $link]]
	if {[info exists tinyurl] && [string length $tinyurl]} {
		return $tinyurl
	} else {
		return $link
	}
}

proc Google:News {args} {
	foreach chan [channels] {
		if {[channel get $chan googlenews]} {
			set news [newsdom]
			set newsdesc [lindex [split $news |] 0]
			set newslink [lindex [split $news |] 1]
			set newstime [lindex [split $news |] end]
			scan $newsdesc {%[^(]} headline
			if {![string match *${newslink}* $::oldnews] && ($headline ni $::oldnews)\
					&& ([expr {([clock seconds] - ${newstime}) < (${::headlinedelay} * 60)}])} {
				if {$::tinyurl < "1" || ![string length $::tinyurl]} {
					news_print $chan "$newsdesc : $newslink ([duration [expr {[clock seconds] - $newstime}]] ago.)"
				} else {
					news_print $chan "$newsdesc : [news_tiny [string trim $newslink]] ([duration [expr {[clock seconds] - $newstime}]] ago.)"
				}
				set ::oldnews $news
			}
		}
	}
	return 0
}

putlog "ok..."
