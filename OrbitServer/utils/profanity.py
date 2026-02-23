"""
Basic profanity filter for chat messages.
Uses a simple word-list approach. Can be swapped for a library later.
"""

# Minimal base list — extend as needed
_BANNED_WORDS = {
    'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'dick', 'pussy', 'nigger',
    'nigga', 'faggot', 'fag', 'slut', 'whore', 'bastard', 'motherfucker',
    'retard', 'kike', 'spic', 'chink', 'wetback',
}


def contains_profanity(text: str) -> bool:
    """Return True if the text contains a banned word."""
    if not text:
        return False
    words = text.lower().split()
    for word in words:
        # Strip punctuation from edges
        clean = word.strip('.,!?;:\'"()[]{}')
        if clean in _BANNED_WORDS:
            return True
    return False


def filter_message(text: str) -> tuple[bool, str]:
    """
    Returns (is_clean, reason).
    is_clean=True means the message is allowed.
    """
    if contains_profanity(text):
        return False, "Message contains prohibited content"
    return True, ""
