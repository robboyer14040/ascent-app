#!/usr/bin/env python3
import re, pathlib, sys

root = pathlib.Path('.')
patterns = [
    (re.compile(r'(objc_msgSendSuper)\s*\('), "objc_msgSendSuper"),
    (re.compile(r'(objc_msgSend)\s*\('), "objc_msgSend"),
    (re.compile(r'(imps\[[^\]]+\])\s*\('), "IMPCALL")
]

# common signatures to suggest (you can choose the right one manually)
signatures = {
    "id_sel": "id (*msgSendTyped)(id, SEL)",
    "void_class_sel": "void (*msgSendVoid)(Class, SEL)",
    "bool_id_sel": "BOOL (*msgSendBool)(id, SEL)",
    "imp_void_class_sel": "void (*impTyped)(Class, SEL)",
    "imp_id_sel_ret": "id (*impIdTyped)(id, SEL)"
}

for path in root.rglob('*.m'):
    txt = path.read_text(encoding='utf-8', errors='ignore')
    for i, line in enumerate(txt.splitlines(), start=1):
        for patt, tag in patterns:
            m = patt.search(line)
            if m:
                snippet = ""
                if tag == "objc_msgSend":
                    snippet = (
                        "// Suggested: cast objc_msgSend to correct signature\n"
                        "// Example (object instance + selector returning id):\n"
                        "id (*msgSendTyped)(id, SEL) = (void *)objc_msgSend;\n"
                        "result = msgSendTyped(receiver, selector);\n"
                    )
                elif tag == "objc_msgSendSuper":
                    snippet = (
                        "// Suggested: cast objc_msgSendSuper to correct signature\n"
                        "void (*msgSendSuperTyped)(struct objc_super *, SEL) = (void *)objc_msgSendSuper;\n"
                        "msgSendSuperTyped(&superStruct, selector);\n"
                    )
                else: # IMPCALL
                    snippet = (
                        "// Suggested: cast IMP before calling\n"
                        "void (*impTyped)(Class, SEL) = (void *){imp};\n"
                        "impTyped(aClass, selectorToCall);\n"
                    )
                    snippet = snippet.replace("{imp}", m.group(1))
                print(f"{path}:{i}: {line.strip()}\n{snippet}")