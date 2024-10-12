create extension if not exists pgcrypto;

create type permission as enum ('writer', 'editor', 'creator');

create table Users
(
    userId      int primary key generated always as identity,
    email       varchar(128) not null unique,
    password    varchar(128) not null,
    userName    varchar(40)  not null unique,
    deactivated bool         not null default false
);

create table Channels
(
    channelId   int primary key generated always as identity,
    channelName varchar(50) not null,
    creatorId   int         not null references Users
        on update cascade
);

create table ChannelParticipants
(
    channelId    int        not null references Channels
        on update cascade
        on delete cascade,
    userId       int        not null references Users
        on update cascade,
    permission   permission not null default 'writer',
    lastViewedAt timestamp           default null,
    removed      bool       not null default false,
    primary key (channelId, userId)
);

create table Messages
(
    messageId       int primary key generated always as identity,
    messageText     varchar(255) not null,
    createdAt       timestamp    not null default now(),
    updatedAt       timestamp             default null,
    deletedAt       timestamp             default null,
    parentMessageId int                   default null references Messages
        on delete cascade
        on update cascade,
    senderId        int          not null references Users
        on update cascade,
    receiverId      int references Users
        on update cascade,
    channelId       int,
    foreign key (senderId, channelId) references ChannelParticipants (userId, channelId)
        on update cascade
);

create table MessageAttachments
(
    attachmentId      int primary key generated always as identity,
    messageId         int          not null references Messages
        on delete cascade
        on update cascade,
    attachmentName    varchar(128) not null,
    attachmentContent text         not null
);

create table MessageFollowers
(
    userId    int not null references Users
        on delete cascade
        on update cascade,
    messageId int not null references Messages
        on delete cascade
        on update cascade,
    primary key (userId, messageId)
);

create table DirectMessagesViews
(
    userId       int       not null references Users
        on update cascade,
    directId     int       not null references Users
        on update cascade,
    lastViewedAt timestamp not null default now(),
    primary key (userId, directId)
);

create table Reactions
(
    reactionName varchar(30) not null,
    messageId    int         not null references Messages
        on delete cascade
        on update cascade,
    userId       int         not null references Users
        on update cascade,
    primary key (reactionName, messageId, userId)
);

-- unreadMessages, unreadThreads
create index direct_views_last_viewed_at_index
    on DirectMessagesViews using btree (lastviewedat)
    include (directid);

-- userThreads, unreadThreads
create index message_followers_userid_index
    on MessageFollowers using hash (userid);

-- messageReactions
create index reactions_messageid_index
    on Reactions using hash (messageid);

-- directs, unreadThreads, unreadMessages
create index messages_receiverid_index
    on Messages using hash (receiverid);

-- deleteThread
create index messages_parentmessageid_index
    on Messages using hash (parentMessageId);

-- unreadThreads, userThreads, directs, unreadMessages
create index messages_senderid_index
    on Messages using hash (senderid);

-- deleteChannel, channelThreads
create index messages_channelid_index
    on Messages using hash (channelid);

-- unreadThreads, unreadMessages, userChannels
create index channelparticipants_userid_index
    on ChannelParticipants using btree (userid, lastviewedat)
    include (channelid)
    where removed = false;

-- deleteChannel
create index channelparticipants_channelid_index
    on ChannelParticipants using hash (channelid);