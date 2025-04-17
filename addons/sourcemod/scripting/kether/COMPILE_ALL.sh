#!/bin/bash
errors=0
for i in *.sp
do ./compile.sh $i || {
	errors=$((errors + 1))
	continue
}
done
if [ "$errors" -gt 0 ]; then
	echo -e "\n$errors plugin(s) failed to compile."
	exit 1
else
	echo -e "\nAll plugins compiled successfully."
	exit 0
fi
