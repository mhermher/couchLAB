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
        DBs = {};
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
                'curl -X GET http://',...
                user,...
                ':', Couch.Users(Self.UserIdx).pass,...
                '@', url,...
                '/_all_dbs'
                ]);
            if error
                throw(MException('CouchConstructor:curl_not_valid', 'System Error, cannot connect to DB'));
            end
            Self.CouchUrl = url;
            response = Couch.parseJSON(json);
            for i = 1:length(response)
                if ~strcmp(response{i}(1), '_')
                    Self.DBs = [Self.DBs; response(i)];
                end
            end
        end
        function Response = Post(Self, DB, Data)
            if ischar(DB)
                if ~any(strcmp(DB, Self.DBs))
                    throw(MException('CouchPOST:DB_not_valid', 'Input DB not in Couch installation'));
                end
            elseif isnumeric(DB)
                if DB < 1 || DB > length(Self.DBs) || mode(DB, 1)
                    throw(MException('CouchPOST:DB_index_not valid', 'Input DB index out of range'));
                end
                DB = Self.DBs{DB};
            else
                throw(MException('CouchPOST:DB_type_not_valid', 'Input DB of invalid type'));
            end
            if ~isstruct(Data)
                throw(MException('CouchPOST:Data_not_valid', 'Input Data not of struct type'));
            end
            Response = cell(length(Data), 2);
            for i = 1:length(Data)
                [error, json] = unix([...
                    'curl -X POST http://',...
                    Couch.Users(Self.UserIdx).user,...
                    ':', Couch.Users(Self.UserIdx).pass,...
                    '@', Self.CouchUrl,...
                    '/', DB,...
                    ' -d ''', Couch.encodeJSON(Data(i)), '''',...
                    ' -H "Content-Type:application/json"']);
                Response{i, 1} = json;
                if error
                    Response{i, 2} = 'System Error. Bad Request';
                else
                    Response{i, 2} = Couch.parseJSON(json);
                end
            end
        end
    end
    
    methods (Static)
        function mat = parseJSON(json)
            switch json(1)
                case '['
                    members = regexp(json, '(\[.*?]|\{.*?}|".*?"|\d*?\.?\d*?)\s*[,\]]', 'tokens');
                    mat = cell(length(members), 1);
                    for i = 1:length(members)
                        mat{i} = Couch.parseJSON(members{i}{1});
                    end
                case '{'
                    mat = struct();
                    members = regexp(json, '"?([\w\$\_][\w\d\$_]*?)"?\s*:\s*(\[.*?\]|\{.*?}|".*?"|\d*?\.?\d*?)\s*[,}]', 'tokens');
                    for i = 1:length(members)
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

