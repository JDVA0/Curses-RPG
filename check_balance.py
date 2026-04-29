
import re

def check_balance(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    # Remove strings and comments
    content = re.sub(r'--.*', '', content)
    content = re.sub(r'"[^"]*"', '""', content)
    content = re.sub(r"'[^']*'", "''", content)
    
    tokens = re.findall(r'\b(if|for|function|do|while|elseif|else|end)\b', content)
    
    stack = []
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in ['if', 'function']:
            stack.append(token)
        elif token in ['for', 'while']:
            stack.append(token)
            if i + 1 < len(tokens) and tokens[i+1] == 'do':
                i += 1
        elif token == 'do':
            stack.append(token)
        elif token == 'end':
            if not stack:
                print(f"Error: Extra 'end' found at token index {i}")
            else:
                stack.pop()
        i += 1
    
    print(f"Final stack: {stack}")

check_balance('enemy.lua')
