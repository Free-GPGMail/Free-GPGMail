# GPGMail Test Cases

All test cases for GPGMail. We would very much appreciate any feedback for tests with the status "TBT" - in particular for those with the comment "Important and simple use case". If possible provide your result in this syntax:
<pre>
$result["ME"]["NN"]["VT"]["NA"]["S"][SEND] = STATUS_OK;
$result["MS"]["NN"]["MT"]["NA"]["S"][RECV] = "#240";
</pre>

## Legend

We've at least five variables for the sending and for the receiving part and therefore 864 (6*4*2*3*3*2) possible combinations. But fortunately we do not have to test every combination (only 324, see table below).

 * A = OpenPGP method
   * **ME**: mime encrypted
   * **MS**: mime signed
   * **MB**: mime both
   * **IE**: inline encrypted
   * **IS**: inline signed
   * **IB**: inline both
 * B = S/MIME method
   * **NN** nothing
   * **EE**: encrypted
   * **SS**: signed
   * **BB**: both
 * C = Message type
   * **VT**: valid text
   * **MT**: modified text
   * Later maybe: **VH** valid HTML and **MH** modified HTML
 * D = Attachment type
   * **NA** none
   * **VA** valid attachment
   * **MA** modified attachment
 * E = Receiver type
   * **S**ingle
   * **M**ultiple
   * **B**CC

That means for example ME/NN/VT/NA/S is an OpenPGP/MIME encrypted message with a valid unmodified text and without an attachment sent to a single person.

## Table

This was generated automatically - please do not edit. Invalid tests (e.g. OpenPGP/MIME + S/MIME) were removed.

### Overview

 * Seems to work (<font color='green'>OK</font>): 37
 * To be tested (<font color='orange'>TBT</font>): 278
 * Has issues (<font color='blue'>#xxx</font>): 9
 * Combination not possible, out of scope or no testing needed (<font color='gray'>INV</font>): 540

### Details

|Nr.  |Test           |Sending                          |Receiving                        |Comment             |
|-----|---------------|---------------------------------|---------------------------------|--------------------|
|0001|ME/NN/VT/NA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0002|ME/NN/VT/NA/M|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0003|ME/NN/VT/NA/B|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0004|ME/NN/VT/VA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0005|ME/NN/VT/VA/M|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0006|ME/NN/VT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0007|ME/NN/VT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0008|ME/NN/VT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0009|ME/NN/VT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0010|ME/NN/MT/NA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0011|ME/NN/MT/NA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0012|ME/NN/MT/NA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0013|ME/NN/MT/VA/S|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0014|ME/NN/MT/VA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0015|ME/NN/MT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0016|ME/NN/MT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0017|ME/NN/MT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0018|ME/NN/MT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0019|MS/NN/VT/NA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0020|MS/NN/VT/NA/M|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0021|MS/NN/VT/NA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0022|MS/NN/VT/VA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0023|MS/NN/VT/VA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0024|MS/NN/VT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0025|MS/NN/VT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0026|MS/NN/VT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0027|MS/NN/VT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0028|MS/NN/MT/NA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0029|MS/NN/MT/NA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0030|MS/NN/MT/NA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0031|MS/NN/MT/VA/S|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0032|MS/NN/MT/VA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0033|MS/NN/MT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0034|MS/NN/MT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0035|MS/NN/MT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0036|MS/NN/MT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0037|MB/NN/VT/NA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0038|MB/NN/VT/NA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0039|MB/NN/VT/NA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0040|MB/NN/VT/VA/S|<font color='green'>OK</font>|<font color='green'>OK</font>|Important and simple use case.|
|0041|MB/NN/VT/VA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0042|MB/NN/VT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>|Important and simple use case.|
|0043|MB/NN/VT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0044|MB/NN/VT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0045|MB/NN/VT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0046|MB/NN/MT/NA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0047|MB/NN/MT/NA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0048|MB/NN/MT/NA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0049|MB/NN/MT/VA/S|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0050|MB/NN/MT/VA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0051|MB/NN/MT/VA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0052|MB/NN/MT/MA/S|<font color='orange'>TBT</font>|<font color='green'>OK</font>||
|0053|MB/NN/MT/MA/M|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0054|MB/NN/MT/MA/B|<font color='orange'>TBT</font>|<font color='orange'>TBT</font>||
|0055|IE/NN/VT/NA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0056|IE/NN/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0057|IE/NN/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0058|IE/NN/VT/VA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/280'>#280</a></font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0059|IE/NN/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0060|IE/NN/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0061|IE/NN/VT/MA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/280'>#280</a></font>| (Sending PGP/Inline not supported)|
|0062|IE/NN/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0063|IE/NN/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0064|IE/NN/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0065|IE/NN/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0066|IE/NN/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0067|IE/NN/MT/VA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>| (Sending PGP/Inline not supported)|
|0068|IE/NN/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0069|IE/NN/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0070|IE/NN/MT/MA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>| (Sending PGP/Inline not supported)|
|0071|IE/NN/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0072|IE/NN/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0073|IE/EE/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0074|IE/EE/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0075|IE/EE/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0076|IE/EE/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0077|IE/EE/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0078|IE/EE/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0079|IE/EE/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0080|IE/EE/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0081|IE/EE/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0082|IE/EE/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0083|IE/EE/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0084|IE/EE/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0085|IE/EE/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0086|IE/EE/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0087|IE/EE/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0088|IE/EE/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0089|IE/EE/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0090|IE/EE/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0091|IE/SS/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0092|IE/SS/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0093|IE/SS/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0094|IE/SS/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0095|IE/SS/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0096|IE/SS/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0097|IE/SS/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0098|IE/SS/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0099|IE/SS/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0100|IE/SS/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0101|IE/SS/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0102|IE/SS/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0103|IE/SS/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0104|IE/SS/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0105|IE/SS/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0106|IE/SS/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0107|IE/SS/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0108|IE/SS/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0109|IE/BB/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0110|IE/BB/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0111|IE/BB/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0112|IE/BB/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0113|IE/BB/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0114|IE/BB/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0115|IE/BB/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0116|IE/BB/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0117|IE/BB/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0118|IE/BB/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0119|IE/BB/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0120|IE/BB/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0121|IE/BB/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0122|IE/BB/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0123|IE/BB/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0124|IE/BB/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0125|IE/BB/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0126|IE/BB/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0127|IS/NN/VT/NA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0128|IS/NN/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0129|IS/NN/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0130|IS/NN/VT/VA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/266'>#266</a></font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0131|IS/NN/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0132|IS/NN/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0133|IS/NN/VT/MA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/283'>#283</a></font>| (Sending PGP/Inline not supported)|
|0134|IS/NN/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0135|IS/NN/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0136|IS/NN/MT/NA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>| (Sending PGP/Inline not supported)|
|0137|IS/NN/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0138|IS/NN/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0139|IS/NN/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0140|IS/NN/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0141|IS/NN/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0142|IS/NN/MT/MA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/281'>#281</a></font>| (Sending PGP/Inline not supported)|
|0143|IS/NN/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0144|IS/NN/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0145|IS/EE/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0146|IS/EE/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0147|IS/EE/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0148|IS/EE/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0149|IS/EE/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0150|IS/EE/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0151|IS/EE/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0152|IS/EE/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0153|IS/EE/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0154|IS/EE/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0155|IS/EE/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0156|IS/EE/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0157|IS/EE/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0158|IS/EE/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0159|IS/EE/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0160|IS/EE/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0161|IS/EE/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0162|IS/EE/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0163|IS/SS/VT/NA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/244'>#244</a></font>| (Sending PGP/Inline not supported)|
|0164|IS/SS/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0165|IS/SS/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0166|IS/SS/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0167|IS/SS/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0168|IS/SS/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0169|IS/SS/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0170|IS/SS/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0171|IS/SS/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0172|IS/SS/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0173|IS/SS/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0174|IS/SS/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0175|IS/SS/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0176|IS/SS/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0177|IS/SS/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0178|IS/SS/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0179|IS/SS/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0180|IS/SS/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0181|IS/BB/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0182|IS/BB/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0183|IS/BB/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0184|IS/BB/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0185|IS/BB/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0186|IS/BB/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0187|IS/BB/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0188|IS/BB/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0189|IS/BB/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0190|IS/BB/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0191|IS/BB/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0192|IS/BB/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0193|IS/BB/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0194|IS/BB/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0195|IS/BB/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0196|IS/BB/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0197|IS/BB/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0198|IS/BB/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0199|IB/NN/VT/NA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0200|IB/NN/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0201|IB/NN/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0202|IB/NN/VT/VA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/239'>#239</a></font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0203|IB/NN/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0204|IB/NN/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>|Important and simple use case. (Sending PGP/Inline not supported)|
|0205|IB/NN/VT/MA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/279'>#279</a></font>| (Sending PGP/Inline not supported)|
|0206|IB/NN/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0207|IB/NN/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0208|IB/NN/MT/NA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>| (Sending PGP/Inline not supported)|
|0209|IB/NN/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0210|IB/NN/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0211|IB/NN/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0212|IB/NN/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0213|IB/NN/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0214|IB/NN/MT/MA/S|<font color='gray'>INV</font>|<font color='green'>OK</font>| (Sending PGP/Inline not supported)|
|0215|IB/NN/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0216|IB/NN/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0217|IB/EE/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0218|IB/EE/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0219|IB/EE/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0220|IB/EE/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0221|IB/EE/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0222|IB/EE/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0223|IB/EE/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0224|IB/EE/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0225|IB/EE/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0226|IB/EE/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0227|IB/EE/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0228|IB/EE/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0229|IB/EE/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0230|IB/EE/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0231|IB/EE/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0232|IB/EE/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0233|IB/EE/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0234|IB/EE/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0235|IB/SS/VT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0236|IB/SS/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0237|IB/SS/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0238|IB/SS/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0239|IB/SS/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0240|IB/SS/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0241|IB/SS/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0242|IB/SS/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0243|IB/SS/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0244|IB/SS/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0245|IB/SS/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0246|IB/SS/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0247|IB/SS/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0248|IB/SS/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0249|IB/SS/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0250|IB/SS/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0251|IB/SS/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0252|IB/SS/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0253|IB/BB/VT/NA/S|<font color='gray'>INV</font>|<font color='blue'><a href='http://gpgtools.lighthouseapp.com/projects/65764/tickets/286'>#286</a></font>| (Sending PGP/Inline not supported)|
|0254|IB/BB/VT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0255|IB/BB/VT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0256|IB/BB/VT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0257|IB/BB/VT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0258|IB/BB/VT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0259|IB/BB/VT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0260|IB/BB/VT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0261|IB/BB/VT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0262|IB/BB/MT/NA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0263|IB/BB/MT/NA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0264|IB/BB/MT/NA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0265|IB/BB/MT/VA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0266|IB/BB/MT/VA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0267|IB/BB/MT/VA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0268|IB/BB/MT/MA/S|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0269|IB/BB/MT/MA/M|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
|0270|IB/BB/MT/MA/B|<font color='gray'>INV</font>|<font color='orange'>TBT</font>| (Sending PGP/Inline not supported)|
