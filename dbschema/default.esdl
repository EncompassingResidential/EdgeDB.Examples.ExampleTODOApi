module default {
    scalar type State extending enum<NotStarted, InProgress, Complete>;

    type TODO {
        required property title -> str {
            constraint exclusive;
            constraint min_len_value(8);
        }
        required property description -> str;
        required property date_created -> std::datetime {
            default := std::datetime_current();
        }
        required property state -> State;
    }
}
