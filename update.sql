create or replace function isUserDeactivated(userId_ Int)
    returns bool
    language plpgsql
as
$$
    begin
        return (select deactivated from users where userid = userId_) = true;
    end;
$$;

create or replace function isChannelParticipant(userId_ Int, channelId_ Int)
    returns bool
    language plpgsql
as
$$
begin
    return userid_ in (select distinct userid
                              from channelparticipants
                              where channelid = channelId_
                                and removed = false);
end;
$$;

create or replace function validateChannelCreator()
    returns trigger
    language plpgsql
as
$$
begin
    if isUserDeactivated(new.creatorid)
    then
        raise 'only active users can create channels';
    end if;

    if new.creatorid <> old.creatorid
    then
        raise 'creator of the channel cannot be updated';
    end if;

    return new;
end;
$$;

create or replace trigger onNewChannel
    before insert or update on channels
    for each row
execute procedure validateChannelCreator();

create or replace function addCreatorToChannel()
    returns trigger
    language plpgsql
as
$$
begin
    insert into channelparticipants (channelid, userid, permission)
    values (new.channelid, new.creatorId, 'creator')
    on conflict do nothing;
    return null;
end;
$$;

create or replace trigger afterChannelCreated
    after insert on Channels
    for each row
execute procedure addCreatorToChannel();

create or replace function validateMessage()
    returns trigger
    language plpgsql
as
$$
    declare grandMessageId int;
    declare parentChannel int;
    declare parentReceiver int;
    declare parentSender int;
begin
    select channelid, receiverid, parentmessageid, senderid
    into parentChannel, parentReceiver, grandMessageId, parentSender
    from messages
    where messageid = new.parentmessageid;

    if new.channelid is null and new.receiverid is null
    then
        raise 'message should be written either to the channel or to the direct';
    end if;

    if grandMessageId is not null
    then
        raise 'messages in the thread cannot be replied';
    end if;

    if isUserDeactivated(new.senderid)
    then
        raise 'only active users can write messages';
    end if;

    if new.channelid is not null
    then
        if not isChannelParticipant(new.senderid, new.channelid)
        then
            raise 'only channel participants can write messages to the channel';
        end if;

        if new.parentmessageid is not null
        then
            if (parentChannel <> new.channelid)
            then
                raise 'parent message should be written in the same channel';
            end if;
        end if;
     end if;

    if new.receiverid is not null
    then
        if isUserDeactivated(new.receiverid)
        then
            raise 'only active users can receive messages';
        end if;

        if new.parentmessageid is not null
        then
            if parentReceiver is null
            then
                raise 'parent message should be written in direct, not in channel';
            end if;
            if parentReceiver <> new.senderid and parentSender <> new.senderid
            then
                raise 'parent message should be written in the same direct';
            end if;
        end if;
    end if;

    return new;
end;
$$;

create or replace trigger onNewMessage
    before insert or update on Messages
    for each row
execute procedure validateMessage();

create or replace function validateFollower()
    returns trigger
    language plpgsql
as
$$
    declare receiver int;
    declare channel int;
    declare sender int;
begin
    if new.messageid not in (select parentmessageid
                              from messages
                              where parentmessageid is not null)
    then
        raise 'only parent messages can be followed';
    end if;

    select receiverid, channelid, senderid
    into receiver, channel, sender
    from messages
    where messageid = new.messageid;

    if receiver is not null
    then
        if new.userid <> receiver and new.userid <> sender
        then
            raise 'messages from the direct chat can be followed only by the direct members';
        end if;
    end if;

    if channel is not null
    then
        if not isChannelParticipant(new.userid, channel)
        then
            raise 'messages from the channel can be followed only by the channel participants';
        end if;
    end if;

    if isUserDeactivated(new.userid)
    then
        raise 'only active users can follow messages';
    end if;

    return new;
end;
$$;

create or replace trigger onNewMessageFollower
    before insert or update on messagefollowers
    for each row
execute procedure validateFollower();

create or replace function validateReaction()
    returns trigger
    language plpgsql
as
$$
    declare receiver int;
    declare channel int;
    declare sender int;
begin
    select receiverid, channelid, senderid
    into receiver, channel, sender
    from messages
    where messageid = new.messageid;

    if (receiver is not null)
    then
        if new.userid <> receiver and new.userid <> sender
        then
            raise 'messages from the direct can be reacted only by the direct members';
        end if;
    end if;

    if channel is not null
    then
        if not isChannelParticipant(new.userid, channel)
        then
            raise 'messages from the channel can be reacted only by the channel participants';
        end if;
    end if;

    if isUserDeactivated(new.userid)
    then
        raise 'only active users can react on messages';
    end if;

    return new;
end;
$$;

create or replace trigger onNewReaction
    before insert or update on reactions
    for each row
execute procedure validateReaction();

create or replace function validateChannelParticipant()
    returns trigger
    language plpgsql
as
$$
begin
    if isUserDeactivated(new.userid)
    then
        raise 'only active users can have an access to the channel';
    end if;

    return new;
end;
$$;

create or replace trigger onNewChannelParticipant
    before insert on channelparticipants
    for each row
execute procedure validateChannelParticipant();

create or replace function validateDirectView()
    returns trigger
    language plpgsql
as
$$
begin
    if isUserDeactivated(new.userid)
    then
        raise 'only active users can view their directs';
    end if;

    return new;
end;
$$;

create or replace trigger onNewDirectView
    before insert on DirectMessagesViews
    for each row
execute procedure validateDirectView();

-- inviteMember – имитирует добавление пользователя в канал другим пользователем
-- isolation level: read committed
create or replace procedure inviteMember(inviter Int, newMember Int, channel Int)
    language plpgsql
as
$$
    declare invitorPermission permission;
    declare invitorRemoved bool;
begin
    if isUserDeactivated(inviter)
    then
        raise 'only active users can invite new members';
    end if;

    select permission, removed
    into invitorPermission, invitorRemoved
    from channelparticipants
    where userid = inviter
      and channelid = channel;

    if invitorRemoved = true
    then
        raise 'invitor is removed from the channel';
    end if;

    if invitorPermission in ('creator', 'editor')
    then
        merge into channelparticipants channel
        using (select newMember as userId, channel as channelId) as n
            on channel.channelid = n.channelId
            and channel.userid = n.userId
        when matched and removed = true then
            update set (permission, removed) = ('writer', false)
        when matched then
            do nothing
        when not matched then
            insert (channelid, userid, permission, lastviewedat, removed)
            values (channel, newMember, 'writer', null, false);
    else
        raise 'user should be in channel and should have editor or creator permissions to invite new members';
    end if;
end;
$$;

-- editMemberPermission — имитирует изменение прав пользователя в канале другим пользователем
-- isolation level: read committed
create or replace procedure editMemberPermission(
    permissionEditor Int,
    member Int,
    channel Int,
    newPermission permission
) language plpgsql as
$$
declare editorPermission_ permission;
declare editorRemoved_ bool;
begin
    if isUserDeactivated(permissionEditor)
    then
        raise 'only active users can change channel members permission';
    end if;

    select permission, removed
    into editorPermission_, editorRemoved_
    from channelparticipants
    where userid = permissionEditor
      and channelid = channel;

    if editorRemoved_ = true
    then
        raise 'permission editor is removed from the channel';
    end if;

    if editorPermission_ = 'creator'
    then
        if member = permissionEditor
        then
            raise 'channel creators cannot edit their permission';
        end if;

        if newPermission = 'creator'
        then
            raise 'channel should not have more than one creator';
        end if;

        update channelparticipants
        set permission = newPermission
        where userid = member
          and channelid = channel;
    else
        raise 'user should be in channel and should have creator permissions to edit permissions of other members';
    end if;
end;
$$;

-- deleteThread – имитирует удаление треда пользователем
-- isolation level: read committed
create or replace procedure deleteThread(
    userId_ Int,
    threadId Int
) language plpgsql as
$$
declare deletedAt_ timestamp;
begin
    deletedAt_ = now();

    if (select count(messageid)
         from messages
         where parentmessageid = threadId) = 0
    then
        raise 'empty thread';
    end if;

    if userId_ <> (select senderid from messages where messageid = threadId)
    then
        raise 'user should not delete threads with parent message which is written by another user';
    end if;

    update messages
    set deletedat = deletedAt_
    where messageid = threadId;
end;
$$;

-- deleteChannel – имитирует удаление канала пользователем
-- isolation level: read committed
create or replace procedure deleteChannel(
    userId_ Int,
    channel Int
) language plpgsql as
$$
begin
    if isUserDeactivated(userid_)
    then
        raise 'only active users can delete the channel';
    end if;

    if userId_ not in (select creatorid from channels where channelid = channel)
    then
        raise 'only channel creator can delete the channel';
    end if;

    delete from messages
    where channelid = channel;

    delete from channels
    where channelid = channel;
end;
$$;