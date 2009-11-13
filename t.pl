 #!/usr/bin/env perl

{
 	local $/; 
 	open(F,"<tmp.log"); 
 	$x=<F>; 
 	close F;
 } 

# <tr>
#     <td class="nWrap">
#         <a ....>2921-2993</a>
#         <sup>
#             </sup>
#         &#160;&#160;
#     </td>
#     <td>
#         <span id="..." class="lblNormalBlackTxt">Joint Tenant</span>
#     </td>
#     <td class="aright" style="padding-right: 10px;">
#         <span id="">$52,249.96</span>
# -----
# <tr id="">
#     <td class="nWrap">
#         <a id="" class="lnkBoldBlue" href="">...820645</a>
#         
#         <sup>
#             2</sup>
#         
#     </td>
#     <td class="nWrap">
#         <span id="..." class="lblNormalBlackTxt">Investor Checking</span>
#         
#     </td>
#     <td style="text-align: right; padding-right: 10px;">
#         <span id="...">$59,621.70</span>
 
(@a) = $x =~   m!  	

				<tr[^>]*>                   \s*

					<td\ class="nWrap">     \s*
						<a[^>]*>            \s*
							([\d-.]+)	    # account number
						</a>                \s*
                        (?: <sup>[^<]*</sup> )?
                        [^<]*
					</td>                   \s*

                    <td[^>]*> \s* <span[^>]*> 
                        ([^<]+)               # account name
                    </span> \s* </td>       \s*
                        
					<td[^>]*>               \s*
                        <span[^>]*>         \s*
						(-?\$[\d,\.]+)		# account balance
                        </span>           

	!sxig;

 
use Data::Dumper;
print Dumper \@a;
 
# print "n=$n\n";
# print "a=$a\n";
# print "b=$b\n";
 
 __END__
 
 
 
<tr height="20" class="spData r1">
<td class="spASValue leftMargin"><a href="https://investing.schwab.com:443/service/?request=ps&subrequest=Balance&psurl=%2Ftrading%2Facctbal%2F%3Fanch=Balance%26NeedCASelValue=Y%26menu=1%26submenu=2%26NewAccountIndex=0">1196-7597</a></td><td class="spASValue rightMargin">$8,061.88</td><td class="spASValue rightMargin">
<div class="flat">$0.00</div>
</td><td style="border-right:0" class="spASValue rightMargin">
<div class="flat">0.00%</div>
</td>

</tr>
<tr height="20" class="spData r0">
<td class="spASValue leftMargin"><a href="https://investing.schwab.com:443/service/?request=ps&subrequest=Balance&psurl=%2Ftrading%2Facctbal%2F%3Fanch=Balance%26NeedCASelValue=Y%26menu=1%26submenu=2%26NewAccountIndex=1">2921-2993</a></td><td class="spASValue rightMargin">$59,931.88</td><td class="spASValue rightMargin">
<div class="up">$288.00</div>
</td><td style="border-right:0" class="spASValue rightMargin">
<div class="up">0.48%</div>
</td>
</tr>
