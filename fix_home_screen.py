import re

with open('lib/screens/home/home_screen.dart', 'r') as f:
    content = f.read()

# Only replace inside _HomeScreenState
state_class_start = content.find('class _HomeScreenState')
if state_class_start != -1:
    pre_state = content[:state_class_start]
    post_state = content[state_class_start:]

    # Replace authService, chatService, etc. with widget.*
    services = ['authService', 'chatService', 'presenceService', 'mediaService', 'backupService']
    for service in services:
        # Match word boundaries that are NOT preceded by 'widget.'
        post_state = re.sub(r'(?<!widget\.)\b{}\b'.format(service), r'widget.{}'.format(service), post_state)
        # Fix double widget.
        post_state = post_state.replace(f'widget.widget.{service}', f'widget.{service}')
        # Fix named parameters if they got incorrectly replaced: e.g. widget.authService: -> authService:
        post_state = post_state.replace(f'widget.{service}:', f'{service}:')

    content = pre_state + post_state

with open('lib/screens/home/home_screen.dart', 'w') as f:
    f.write(content)

