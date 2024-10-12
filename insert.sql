insert into Users (email, password, username, deactivated)
values ('ivanov@yandex.ru', crypt('pass1', gen_salt('bf')), 'ivanov', false),
       ('sidorov@yandex.ru', crypt('pass2', gen_salt('bf')), 'sidorov', false),
       ('alekseev@yandex.ru', crypt('pass2', gen_salt('bf')), 'alekseev', false),
       ('smirnov@yandex.ru', crypt('very very very very very very very very very very' ||
                                   'very very very very very very very very very very very very long password ' ||
                                   'greater than 128 symbols', gen_salt('bf')), 'smirnov', false),
       ('norris@yandex.ru', crypt('pass3', gen_salt('bf')), 'chak', true);


insert into channels (channelname, creatorid)
values ('offtopic', 1),
       ('town-square', 2),
       ('general', 1),
       ('basket', 3);

insert into channelparticipants (channelid, userid, permission, lastviewedat, removed)
values (1, 2, 'editor', timestamp '2024-01-15 11:37:54', true),
       (1, 3, 'writer', timestamp '2024-01-15 11:40:58', false),
       (1, 4, 'writer', timestamp '2024-01-14 17:20:54', false),
       (3, 2, 'writer', timestamp '2024-01-14 14:03:02', false),
       (4, 1, 'writer', timestamp '2024-01-09 14:03:02', false),
       (4, 4, 'editor', timestamp '2024-01-09 14:03:02', false),
       (2, 1, 'writer', timestamp '2024-01-09 14:03:02', false);

insert into messages (messagetext, createdat, updatedat, deletedat, parentmessageid, senderid, receiverid, channelid)
values ('а роза', timestamp '2024-01-15 10:23:54', timestamp '2024-01-15 11:35:54', timestamp '2024-01-15 12:47:54', null, 1, null, 1),
       ('упала', timestamp '2024-01-15 10:24:51', timestamp '2024-01-15 11:36:30', null, null, 3, null, 1),
       ('на лапу Азора!',  timestamp '2024-01-15 10:24:51', null, null, null, 1, null, 1),
       ('Привет! проверь плиз МР',  timestamp '2024-01-15 17:11:37', null, null, null, 3, 4, null),
       ('Не сейчас. Я занят', timestamp '2024-01-16 14:33:07', null, null, 4, 4, 3, null),
       ('Всем привет! Работает ли ещё у нас Чак Норрис?', timestamp '2024-01-14 13:59:37', null, null, null, 2, null, 3),
       ('Нет', timestamp '2024-01-14 14:03:02', null, null, 6, 1, null, 3),
       ('Не-а, он уволился, и его аккаунт в мессенджере деактивировали', timestamp '2024-01-14 14:04:02', null, null, 6, 1, null, 3),
       ('Для чего нужен этот канал?', timestamp '2024-01-15 20:21:23', null, null, null, 4, null, 4),
       ('Привет!', timestamp '2024-01-15 20:20:23', null, null, null, 1, null, 4),
       ('Привет!', timestamp '2024-01-15 20:20:23', null, null, null, 1, null, 2);


insert into messageattachments (messageid, attachmentname, attachmentcontent)
values (8, 'договор об увольнении', 'Я устал, я ухожу. Чак Норрис, 11.01.2024'),
       (8, 'характеристика Чака Норриса', 'Он был честным, трудолюбивым, правда зачем-то открутил колесо моего кресла...'),
       (4, 'аналитика задачи', 'в рамках доработки требуется внедрить СБП C2C international'),
       (4, 'аналитика задачи', 'UPD: ещё нужно баги X, Y, Z пофиксить');

insert into reactions (reactionname, messageid, userid)
values (':parrot:', 2, 1),
       (':friday dog:', 2, 1),
       (':fire:', 2, 3),
       (':parrot:', 3, 1),
       (':smile:', 3, 4),
       (':pray:', 5, 3),
       (':NO:', 5, 4),
       (':May be next time:', 5, 4);

insert into messagefollowers (userid, messageid)
values (3, 4),
       (4, 4),
       (1, 6),
       (2, 6);

insert into directmessagesviews (userId, directId, lastViewedAt)
values (4, 3, timestamp '2024-01-16 14:33:09'),
       (3, 4, timestamp '2024-01-16 13:20:16');
