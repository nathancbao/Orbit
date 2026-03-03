"""
Profanity filter for chat messages and tags.
Uses better-profanity with a custom word list extension.
"""

from better_profanity import profanity

_CUSTOM_WORDS = ['gooning']

profanity.load_censor_words(custom_words=_CUSTOM_WORDS)


def contains_profanity(text: str) -> bool:
    """Return True if the text contains a banned word."""
    if not text:
        return False
    return profanity.contains_profanity(text)


def filter_message(text: str) -> tuple[bool, str]:
    """
    Returns (is_clean, reason).
    is_clean=True means the message is allowed.
    """
    if contains_profanity(text):
        return False, "Message contains prohibited content"
    return True, ""
