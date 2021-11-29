if [ -z "$1" ]; then
	echo "Output directory has to be specified!"
	exit 1
fi

ROOT="/"
OUTDIR="$1"
CLASS_DUMP_EXECUTABLE="/Users/lukele/Developer/Projects/GPGTools/symbols/symbols/class-dump/build/Release/class-dump"
if [[ -n "$2" && -d "$2" ]]; then
	ROOT="$2"
fi

ADDRESS_FLAGS=""
if [[ -n "$3" ]]; then
	ADDRESS_FLAGS=""
fi

$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/MailUI" "$ROOT/Applications/Mail.app/Contents/MacOS/Mail"
$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/EmailAddressing" "$ROOT/System/Library/PrivateFrameworks/EmailAddressing.framework/EmailAddressing" 
$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/MailCore" "$ROOT/System/Library/PrivateFrameworks/MailCore.framework/MailCore"
$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/MailUIFW" "$ROOT/System/Library/PrivateFrameworks/MailUI.framework"
$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/MailFW" "$ROOT/System/Library/PrivateFrameworks/Mail.framework"
$CLASS_DUMP_EXECUTABLE $ADDRESS_FLAGS -I -H -o "$OUTDIR/IMAP" "$ROOT/System/Library/PrivateFrameworks/IMAP.framework"
