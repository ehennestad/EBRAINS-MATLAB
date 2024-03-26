function [parameters, operationIDs] = extractParametersAndOperationID(cellArray)
    % Initialize empty arrays to store extracted data
    parameters = {};
    operationIDs = {};

    % Regular expression pattern to match parameter name:description pairs
    paramPattern = '<li>([^:]+): ([^<]+)</li>';

    % Regular expression pattern to match operationID
    operationPattern = '"operationId":"([^"]+)"';

    % Iterate through each cell in the cell array
    for i = 1:numel(cellArray)
        % Extract the string from the cell
        str = cellArray{i};

        % Use regular expression to match parameter name:description pairs
        paramMatches = regexp(str, paramPattern, 'tokens');

        % Use regular expression to match operationID
        operationMatch = regexp(str, operationPattern, 'tokens', 'once');

        % Check if matches are found
        if ~isempty(paramMatches) && ~isempty(operationMatch)
            % Extract parameters and operationID
            parameters{i} = paramMatches;
            operationIDs{i} = operationMatch{1};
        end
    end

    % Display extracted data
    for i = 1:numel(parameters)
        fprintf('Operation ID: %s\n', operationIDs{i});
        fprintf('Parameters:\n');
        for j = 1:numel(parameters{i})
            paramName = parameters{i}{j}{1};
            paramDesc = parameters{i}{j}{2};
            fprintf('    %s: %s\n', paramName, paramDesc);
        end
        fprintf('\n');
    end
end
