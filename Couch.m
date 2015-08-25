classdef Couch
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Constant, Hidden, GetAccess = private)
        Users = [...
            struct('user', 'openuser', 'pass', 'openpassword')
            ];
    end
    
    properties (GetAccess = private, SetAccess = private)
        UserIdx = [];
        CouchUrl = '';
    end
    
    properties (GetAccess = public, SetAccess = private)
        DBs = struct.empty();
    end
    
    methods
        function Self = Couch(url, user)
            if ~ischar(url)
                throw(MException('CouchConstructor:url_not_char', 'Input url not char type'));
            end
            if ~ischar(user)
                throw(MException('CouchConstructor:user_not_char', 'Input user not char type'));
            end
            UserMatch = strcmp({Couch.Users.user}, user);
            if sum(UserMatch) ~= 1
                throw(MException('CouchContructor:user_not_unique', 'Input user not unique'));
            end
            Self.UserIdx = find(UserMatch);
            [error, json] = unix([...
                'curl -X GET ''http://',...
                user,...
                ':', Couch.Users(Self.UserIdx).pass,...
                '@', url,...
                '/_all_dbs'''...
                ]);
            if error
                throw(MException('CouchConstructor:curl_not_valid', 'System Error, cannot connect to DB'));
            end
            Self.CouchUrl = url;
            DBResponse = Couch.parseJSON(json);
            for i = 1:length(DBResponse)
                if ~strcmp(DBResponse{i}(1), '_')
                    Self.DBs = [Self.DBs; struct('name', DBResponse{i})];
                    Self.DBs(end).designs = struct.empty();
                    [error, json] = unix([...
                        'curl -X GET ''http://',...
                        user,...
                        ':', Couch.Users(Self.UserIdx).pass,...
                        '@', url,...
                        '/', DBResponse{i},...
                        '/_all_docs?startkey="_design/"&endkey="_design0"'''...
                        ]);
                    if ~error
                        DgnResponse = Couch.parseJSON(json);
                        for j = 1:length(DgnResponse.rows)
                            Self.DBs(end).designs = [Self.DBs(end).designs; struct('name', DgnResponse.rows(j).key(9:end))];
                            Self.DBs(end).designs(end).views = {};
                            [error, json] = unix([...
                                'curl -X GET ''http://',...
                                user,...
                                ':', Couch.Users(Self.UserIdx).pass,...
                                '@', url,...
                                '/', DBResponse{i},...
                                '/_design/', DgnResponse.rows(j).key(9:end), ''''...
                                ]);
                            if ~error
                                VwResponse = Couch.parseJSON(json);
                                Self.DBs(end).designs(end).views = fieldnames(VwResponse.views);
                            end
                        end
                    end
                end
            end
        end
        function Response = Post(Self, DB, Data)
            if ischar(DB)
                if ~any(strcmp(DB, {Self.DBs.name}'))
                    throw(MException('CouchPOST:DB_not_valid', 'Input DB not in Couch installation'));
                end
                DB = Self.DBs(strcmp(DB, {Self.DBs.name}'));
            elseif isnumeric(DB)
                if DB < 1 || DB > length(Self.DBs) || mod(DB, 1)
                    throw(MException('CouchPOST:DB_index_not_valid', 'Input DB index out of range'));
                end
                DB = Self.DBs(DB);
            else
                throw(MException('CouchPOST:DB_type_not_valid', 'Input DB of invalid type'));
            end
            if ~isstruct(Data)
                throw(MException('CouchPOST:Data_not_valid', 'Input Data not of struct type'));
            end
            Response = cell(length(Data), 1);
            for i = 1:length(Data)
                [error, json] = unix([...
                    'curl -X POST ''http://',...
                    Couch.Users(Self.UserIdx).user,...
                    ':', Couch.Users(Self.UserIdx).pass,...
                    '@', Self.CouchUrl,...
                    '/', DB.name,...
                    ''' -d ''', Couch.encodeJSON(Data(i)), '''',...
                    ' -H "Content-Type:application/json"']);
                if error
                    Response{i} = struct.empty();
                else
                    Response{i} = Couch.parseJSON(json);
                end
            end
        end
        function Response = Get(Self, DB, Design, View)
            if ischar(DB)
                if ~any(strcmp(DB, {Self.DBs.name}'))
                    throw(MException('CouchGET:DB_not_valid', 'Input DB not in Couch installation'));
                end
                DB = Self.DBs(strcmp(DB, {Self.DBs.name}'));
            elseif isnumeric(DB)
                if DB < 1 || DB > length(Self.DBs) || mod(DB, 1)
                    throw(MException('CouchGET:DB_index_not_valid', 'Input DB index out of range'));
                end
                DB = Self.DBs(DB);
            else
                throw(MException('CouchGET:DB_type_not_valid', 'Input DB of invalid type'));
            end
            if ischar(Design)
                if ~any(strcmp(Design, {DB.designs.name}'))
                    throw(MException('CouchGET:Design_not_valid', 'Input Design not in input DB'));
                end
                Design = DB.designs(strcmp(Design, {DB.designs.name}'));
            elseif isnumeric(Design)
                if Design < 1 || Design > length(DB.designs) || mod(Design, 1)
                    throw(MException('CouchGET:Design_index_not_valid', 'Input Design index out of range'));
                end
                Design = DB.designs(Design);
            else
                throw(MException('CouchGET:Design_type_not_valid', 'Input Design of invalid type'));
            end
            if ischar(View)
                ViewParts = regexp(View, '([^\?]*)(.*)?', 'tokens');
                View = ViewParts{1}{1};
                Where = ViewParts{1}{2};
                if ~any(strcmp(View, Design.views))
                    throw(MException('CouchGET:View_not_valid', 'Input View not in input Design'));
                end
            elseif isnumeric(View)
                if View < 1 || View > length(Design.views) || mod(View, 1)
                    throw(MException('CouchGET:View_index_not_valid', 'Input View index out of range'));
                end
                View = Design.views{View};
            else
                throw(MException('CouchGET:View_type_not_valid', 'Input View of invalid type'));
            end
            [error, json] = unix([...
                'curl -X GET ''http://',...
                Couch.Users(Self.UserIdx).user,...
                ':', Couch.Users(Self.UserIdx).pass,...
                '@', Self.CouchUrl,...
                '/', DB.name,...
                '/_design/', Design.name,...
                '/_view/', View, Where
                ]);
            if error
                Response = struct.empty();
            else
                Response = Couch.parseJSON(json);
                if isfield(Response, 'rows')
                    Response = Response.rows;
                end
            end
        end
    end
    
    methods (Static)
        function mat = parseJSON(json)
            switch json(1)
                case '['
                    members = regexp(json, '(\[.*?]|\{.*?}|".*?"|\d*?\.?\d*?)\s*[,\]]', 'tokens');
                    mat = [];
                    for i = 1:length(members)
                        member = Couch.parseJSON(members{i}{1});
                        if ischar(member)
                            mat = [mat; {member}];
                        else
                            mat = [mat; member];
                        end
                    end
                case '{'
                    mat = struct();
                    members = regexp(json, '"?([\w\$\_][\w\d\$_]*?)"?\s*:\s*(\[.*?\]|\{.*?}|".*?"|\d*?\.?\d*?)\s*[,}]', 'tokens');
                    for i = 1:length(members)
                        if strcmp(members{i}{1}(1), '_')
                            members{i}{1} = ['u' members{i}{1}];
                        end
                        mat.(members{i}{1}) = Couch.parseJSON(members{i}{2});
                    end
                case '"'
                    mat = json(2:end-1);
                otherwise
                    mat = str2double(json);
            end
        end
        function json = encodeJSON(mat)
            if ischar(mat)
                json = ['"' strrep(strrep(mat, '"', ''''), '''', '''"''"''') '"'];
            elseif length(mat) > 1
                json = '[';
                for i = 1:length(mat)
                    json = [json Couch.encodeJSON(mat(i)) ', '];
                end
                json = [json(1:end-2) ']'];
            else
                switch class(mat)
                    case 'cell'
                        if isempty(mat)
                            json = '[]';
                        else
                            json = Couch.encodeJSON(mat{1});
                        end
                    case 'double'
                        if isempty(mat)
                            json = '[]';
                        else
                            json = num2str(mat);
                        end
                    case 'struct'
                        if isempty(mat)
                            json = '{}';
                        else
                            members = fieldnames(mat);
                            json = '{';
                            for i = 1:length(members)
                                if isempty(mat.(members{i}))
                                    continue;
                                end
                                json = [json '"' members{i} '" : ' Couch.encodeJSON(mat.(members{i})) ', '];
                            end
                            json = [json(1:end-2) '}'];
                        end
                end
            end
        end
    end
    
end

