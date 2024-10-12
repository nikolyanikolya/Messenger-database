-- viewedDirectMessages — просмотренные директы
create or replace view viewedDirectMessages as
select m.messageid, m.messagetext
from messages m
where m.senderid in (
    select directid
    from directmessagesviews
    where lastviewedat >= m.createdat
);

-- threadMessages — треды и пользователи, отправившие сообщения в них
create or replace view threadMessages as
    select distinct parentmessageid, senderid
    from messages
    where parentmessageid is not null;

-- threads – все треды
create or replace view threads as
    select distinct parentmessageid
    from threadMessages;

-- userChannels — каналы, в которых участвует пользователь
create or replace function userChannels(IN userName_ varchar(40))
returns table (channelName varchar(50)) as
$$
declare userId_ int;
BEGIN
    select u.userid into userId_
    from users u
    where u.username = userName_;

    return query
    select c.channelname
    from channels c
    where channelid in (
        select channelid
        from channelparticipants
        where userid = userId_
          and removed = false
    );
end;
$$
language 'plpgsql';

select channelname from userChannels(cast('sidorov' as varchar(40)));

-- directs — непустые личные чаты пользователя.
create or replace function directs(IN userName_ varchar(40))
    returns table (userName varchar(50)) as
$$
declare userId_ int;
BEGIN
    select u.userid into userId_
    from users u
    where u.username = userName_;

    return query
    select u.username
    from users u
    where userid in (
        select receiverid
        from messages
        where senderid = userId_
        union
        select senderid
        from messages
        where receiverid = userId_
    );
end;
$$
language 'plpgsql';

select username from directs('chak');
select username from directs('sidorov');
select username from directs('smirnov');
select username from directs('alekseev');
select username from directs('ivanov');

-- unreadMessages – новые сообщения для пользователя (которые пользователь ещё не видел),
-- могут быть в директе и в каналах
create or replace function unreadMessages(IN userName_ varchar(40))
returns table (messageId int, messageText varchar(255), source varchar(10)) as
$$
    declare userId_ int;
    declare directType varchar(10);
    declare channelType varchar(10);
    begin
        select u.userid into userId_
        from users u
        where u.username = userName_;

        select cast('channel' as varchar(10)) into channelType;
        select cast('direct' as varchar(10)) into directType;

        return query
        select m.messageid, m.messagetext, channelType as source
        from messages m
        where m.channelid in (
            select channelid
            from channelparticipants
            where userid = userId_
              and removed = false
              and (lastviewedat is null or
                lastviewedat < m.createdat)
        )
        union
        (select m.messageid, m.messagetext, directType as source
         from messages m
         where m.receiverid = userId_
         except all
         select v.messageid, v.messagetext, directType as source
         from viewedDirectMessages v);
    end
$$
language 'plpgsql';

select messageId, messageText, source from unreadMessages('alekseev');

-- 	messageReactions – статистика реакций на сообщении
create or replace function messageReactions(IN messageId_ int)
    returns table (reactionName varchar(30), reactionCnt bigint) as
$$
    begin
        return query
        select r.reactionName, count(userid) as reactionCnt
        from reactions r
        where messageid = messageId_
        group by r.reactionName;
    end;
$$
language 'plpgsql';

select reactionname, reactionCnt from messageReactions(2);
select reactionname, reactionCnt from messageReactions(5);

-- channelThreads – треды канала и их длины (без учёта родительского сообщения)
create or replace function channelThreads(IN channelId_ int)
    returns table (parentmessageid int, threadLength bigint) as
$$
    begin
        return query
        select m.parentmessageid, count(messageid) as threadLength
        from messages m
        where channelid = channelId_
          and m.parentmessageid is not null
        group by m.parentmessageid;
    end;
$$
language 'plpgsql';

select parentmessageid, threadLength from channelThreads(3);


-- userThreads – треды, в которых участвует пользователь
-- (либо подписан на родительское сообщение, либо пишет сообщение в треде, либо написал родительское сообщение)
create or replace function userThreads(IN userName_ varchar(40))
    returns table (parentMessageId int) as
$$
declare userId_ int;
begin
    select u.userid into userId_
    from users u
    where u.username = userName_;

    return query
    select distinct t.parentmessageid
    from threadMessages t
    where senderid = userId_
    union
    select distinct messageId
    from messagefollowers
    where userid = userid_
    union
    select distinct messageid
    from messages
    where senderid = userId_
      and messageid in (
        select t.parentmessageid
        from threads t
    );
end;
$$
language 'plpgsql';

select parentmessageid from userThreads('sidorov');
select parentmessageid from userThreads('ivanov');
select parentmessageid from userThreads('alekseev');
select parentmessageid from userThreads('smirnov');
select parentmessageid from userThreads('chak');


-- unreadThreads – треды, в которых участвует пользователь, и в которых есть непрочитанные сообщения
-- (считается, что тред прочтён, когда просмотрен канал, в котором он находится)
create or replace function unreadThreads(IN userName_ varchar(40))
    returns table (parentMessageId int) as
$$
declare userId_ int;
begin
    select u.userid into userId_
    from users u
    where u.username = userName_;

    return query
    select distinct m.parentmessageid
    from messages m
    where m.parentmessageid in (
        select distinct t.parentmessageid
        from threadMessages t
        where senderid = userId_
        union
        select distinct messageId
        from messagefollowers
        where userid = userid_
        union
        select distinct messageid
        from messages
        where senderid = userId_
          and messageid in (
            select t.parentmessageid
            from threads t
    )) and messageid in (
        select m.messageid
        from messages m
        where m.channelid in (
             select channelid
             from channelparticipants
             where userid = userId_
               and removed = false
               and (lastviewedat is null or
                   lastviewedat < m.createdat)
        )
        union
        (select m.messageid
         from messages m
         where m.receiverid = userId_
         except all
         select v.messageid
         from viewedDirectMessages v)
    );
end
$$
language 'plpgsql';

select parentMessageId from unreadthreads('sidorov');
select parentmessageid from unreadThreads('ivanov');
select parentmessageid from unreadthreads('alekseev');
select parentmessageid from unreadThreads('smirnov');
select parentmessageid from unreadthreads('chak');