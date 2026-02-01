# Overview - by Leo
This folder is AI logic for scoring interest matching (MatchingEngine), creating groups (GroupManager), and recommending events (EventSuggester). 

## Matching Engine
Does the actual matching based on the scoring based on Jaccard Similarity

## GroupManager
Creates groups based on an interest and recommends based on interests if not already a member

## EventSuggester
- As the name implies, it recommends students events based on event tags and student interests

## MLEventRecommender
- Uses online gradient descent to personalize event recommendations per student
- Maintains a learned weight vector over Interest categories for each student
- Students give like/dislike feedback on events; the model updates weights accordingly
- Weights converge over time — liked categories rise toward 1.0, disliked toward 0.0
- Each student has an independent model, so recommendations are personalized

## Models
- Defines the scoring heuristic
- Defines what groups, events, students, interests, feedback, and feedback records are and their respective fields.
