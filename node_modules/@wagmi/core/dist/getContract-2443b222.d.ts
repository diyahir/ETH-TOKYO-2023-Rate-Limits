import { Abi, ResolvedConfig, Address, AbiStateMutability, Narrow, ExtractAbiFunctionNames, AbiFunction, ExtractAbiFunction, AbiParametersToPrimitiveTypes, AbiParameterToPrimitiveType, AbiEvent, AbiParameter, ExtractAbiEventNames, ExtractAbiEvent } from 'abitype';
import { ethers, Signer, providers, Contract as Contract$2 } from 'ethers';

/**
 * Count occurrences of {@link TType} in {@link TArray}
 *
 * @param TArray - Array to count occurrences in
 * @param TType - Type to count occurrences of
 * @returns Number of occurrences of {@link TType} in {@link TArray}
 *
 * @example
 * type Result = CountOccurrences<['foo', 'bar', 'foo'], 'foo'>
 */
type CountOccurrences<TArray extends readonly unknown[], TType> = FilterNever<[
    ...{
        [K in keyof TArray]: TArray[K] extends TType ? TArray[K] : never;
    }
]>['length'];
/**
 * Removes all occurrences of `never` from {@link TArray}
 *
 * @param TArray - Array to filter
 * @returns Array with `never` removed
 *
 * @example
 * type Result = FilterNever<[1, 2, never, 3, never, 4]>
 */
type FilterNever<TArray extends readonly unknown[]> = TArray['length'] extends 0 ? [] : TArray extends [infer THead, ...infer TRest] ? IsNever<THead> extends true ? FilterNever<TRest> : [THead, ...FilterNever<TRest>] : never;
/**
 * Check if {@link T} is `never`
 *
 * @param T - Type to check
 * @returns `true` if {@link T} is `never`, otherwise `false`
 *
 * @example
 * type Result = IsNever<'foo'>
 */
type IsNever<T> = [T] extends [never] ? true : false;
/**
 * Checks if {@link T} is `unknown`
 *
 * @param T - Type to check
 * @returns `true` if {@link T} is `unknown`, otherwise `false`
 *
 * @example
 * type Result = IsUnknown<unknown>
 */
type IsUnknown<T> = unknown extends T ? true : false;
/**
 * Joins {@link Items} into string separated by {@link Separator}
 *
 * @param Items - Items to join
 * @param Separator - Separator to use
 * @returns Joined string
 *
 * @example
 * type Result = Join<['foo', 'bar'], '-'>
 */
type Join<Items extends string[], Separator extends string | number> = Items extends [infer First, ...infer Rest] ? First extends string ? Rest extends string[] ? Rest extends [] ? `${First}` : `${First}${Separator}${Join<Rest, Separator>}` : never : never : '';
/**
 * Converts {@link Union} to intersection
 *
 * @param Union - Union to convert
 * @returns Intersection of {@link Union}
 *
 * @example
 * type Result = UnionToIntersection<'foo' | 'bar'>
 */
type UnionToIntersection<Union> = (Union extends unknown ? (arg: Union) => unknown : never) extends (arg: infer R) => unknown ? R : never;

type Contract$1<TAbi extends Abi | readonly unknown[] = Abi | readonly unknown[], TFunctionName extends string = string> = {
    abi: TAbi;
    functionName: TFunctionName;
};
type GetConfig<TAbi extends Abi | readonly unknown[] = Abi, TFunctionName extends string = string, TAbiStateMutability extends AbiStateMutability = AbiStateMutability> = {
    /** Contract ABI */
    abi: Narrow<TAbi>;
    /** Contract address */
    address: Address;
    /** Function to invoke on the contract */
    functionName: GetFunctionName<TAbi, TFunctionName, TAbiStateMutability>;
} & GetArgs<TAbi, TFunctionName>;
type GetFunctionName<TAbi extends Abi | readonly unknown[] = Abi, TFunctionName extends string = string, TAbiStateMutability extends AbiStateMutability = AbiStateMutability> = TAbi extends Abi ? ExtractAbiFunctionNames<TAbi, TAbiStateMutability> extends infer AbiFunctionNames ? AbiFunctionNames | (TFunctionName extends AbiFunctionNames ? TFunctionName : never) | (Abi extends TAbi ? string : never) : never : TFunctionName;
type GetArgs<TAbi extends Abi | readonly unknown[], TFunctionName extends string, TAbiFunction extends AbiFunction & {
    type: 'function';
} = TAbi extends Abi ? ExtractAbiFunction<TAbi, TFunctionName> : AbiFunction & {
    type: 'function';
}, TArgs = AbiParametersToPrimitiveTypes<TAbiFunction['inputs']>, FailedToParseArgs = ([TArgs] extends [never] ? true : false) | (readonly unknown[] extends TArgs ? true : false)> = true extends FailedToParseArgs ? {
    /**
     * Arguments to pass contract method
     *
     * Use a [const assertion](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-3-4.html#const-assertions) on {@link abi} for type inference.
     */
    args?: readonly unknown[];
} : TArgs extends readonly [] ? {
    args?: never;
} : {
    /** Arguments to pass contract method */ args: TArgs;
};
type GetReturnType<TAbi extends Abi | readonly unknown[] = Abi, TFunctionName extends string = string, TAbiFunction extends AbiFunction & {
    type: 'function';
} = TAbi extends Abi ? ExtractAbiFunction<TAbi, TFunctionName> : AbiFunction & {
    type: 'function';
}, TArgs = AbiParametersToPrimitiveTypes<TAbiFunction['outputs']>, FailedToParseArgs = ([TArgs] extends [never] ? true : false) | (readonly unknown[] extends TArgs ? true : false)> = true extends FailedToParseArgs ? unknown : TArgs extends readonly [] ? void : TArgs extends readonly [infer Arg] ? Arg : TArgs & {
    [Output in TAbiFunction['outputs'][number] as Output extends {
        name: infer Name extends string;
    } ? Name extends '' ? never : Name : never]: AbiParameterToPrimitiveType<Output>;
};
type MAXIMUM_DEPTH = 20;
/**
 * ContractsConfig reducer recursively unwraps function arguments to infer/enforce type param
 */
type ContractsConfig<TContracts extends Contract$1[], TProperties extends Record<string, any> = object, Result extends any[] = [], Depth extends ReadonlyArray<number> = []> = Depth['length'] extends MAXIMUM_DEPTH ? (GetConfig & TProperties)[] : TContracts extends [] ? [] : TContracts extends [infer Head extends Contract$1] ? [
    ...Result,
    GetConfig<Head['abi'], Head['functionName'], 'pure' | 'view'> & TProperties
] : TContracts extends [
    infer Head extends Contract$1,
    ...infer Tail extends Contract$1[]
] ? ContractsConfig<[
    ...Tail
], TProperties, [
    ...Result,
    GetConfig<Head['abi'], Head['functionName'], 'pure' | 'view'> & TProperties
], [
    ...Depth,
    1
]> : unknown[] extends TContracts ? TContracts : TContracts extends GetConfig<infer TAbi, infer TFunctionName>[] ? (GetConfig<TAbi, TFunctionName> & TProperties)[] : (GetConfig & TProperties)[];
/**
 * ContractsResult reducer recursively maps type param to results
 */
type ContractsResult<TContracts extends Contract$1[], Result extends any[] = [], Depth extends ReadonlyArray<number> = []> = Depth['length'] extends MAXIMUM_DEPTH ? GetReturnType[] : TContracts extends [] ? [] : TContracts extends [infer Head extends Contract$1] ? [...Result, GetReturnType<Head['abi'], Head['functionName']>] : TContracts extends [
    infer Head extends Contract$1,
    ...infer Tail extends Contract$1[]
] ? ContractsResult<[
    ...Tail
], [
    ...Result,
    GetReturnType<Head['abi'], Head['functionName']>
], [
    ...Depth,
    1
]> : TContracts extends GetConfig<infer TAbi, infer TFunctionName>[] ? GetReturnType<TAbi, TFunctionName>[] : GetReturnType[];
/**
 * Get name for {@link AbiFunction} or {@link AbiEvent}
 *
 * @param TAbiItem - {@link AbiFunction} or {@link AbiEvent}
 * @param IsSignature - Whether to return the signature instead of the name
 * @returns Name or signature of function or event
 *
 * @example
 * type Result = AbiItemName<{ type: 'function'; name: 'Foo'; … }>
 */
type AbiItemName<TAbiItem extends (AbiFunction & {
    type: 'function';
}) | AbiEvent, IsSignature extends boolean = false> = IsSignature extends true ? TAbiItem['inputs'] extends infer TAbiParameters extends readonly AbiParameter[] ? `${TAbiItem['name']}(${Join<[
    ...{
        [K in keyof TAbiParameters]: TAbiParameters[K]['type'];
    }
], ','>})` : never : TAbiItem['name'];
/**
 * Get overrides for {@link AbiStateMutability}
 *
 * @param TAbiStateMutability - {@link AbiStateMutability}
 * @returns Overrides for {@link TAbiStateMutability}
 *
 * @example
 * type Result = GetOverridesForAbiStateMutability<'pure'>
 */
type GetOverridesForAbiStateMutability<TAbiStateMutability extends AbiStateMutability> = {
    nonpayable: Overrides & {
        from?: Address;
    };
    payable: PayableOverrides & {
        from?: Address;
    };
    pure: CallOverrides;
    view: CallOverrides;
}[TAbiStateMutability];
interface Overrides extends ethers.Overrides {
    gasLimit?: ResolvedConfig['BigIntType'];
    gasPrice?: ResolvedConfig['BigIntType'];
    maxFeePerGas?: ResolvedConfig['BigIntType'];
    maxPriorityFeePerGas?: ResolvedConfig['BigIntType'];
    nonce?: ResolvedConfig['IntType'];
}
interface PayableOverrides extends Overrides {
    value?: ResolvedConfig['IntType'] | ResolvedConfig['BigIntType'];
}
interface CallOverrides extends PayableOverrides {
    blockTag?: ethers.CallOverrides['blockTag'];
    from?: Address;
}
type Event<TAbiEvent extends AbiEvent> = Omit<ethers.Event, 'args' | 'event' | 'eventSignature'> & {
    args: AbiParametersToPrimitiveTypes<TAbiEvent['inputs']>;
    event: TAbiEvent['name'];
    eventSignature: AbiItemName<TAbiEvent, true>;
};

type GetContractArgs<TAbi extends Abi | readonly unknown[] = Abi> = {
    /** Contract address */
    address: string;
    /** Contract ABI */
    abi: Narrow<TAbi>;
    /** Signer or provider to attach to contract */
    signerOrProvider?: Signer | providers.Provider;
};
type GetContractResult<TAbi = unknown> = TAbi extends Abi ? Contract<TAbi> & Contract$2 : Contract$2;
declare function getContract<TAbi extends Abi | readonly unknown[]>({ address, abi, signerOrProvider, }: GetContractArgs<TAbi>): GetContractResult<TAbi>;
type PropertyKeys = 'address' | 'attach' | 'connect' | 'deployed' | 'interface' | 'resolvedAddress';
type FunctionKeys = 'callStatic' | 'estimateGas' | 'functions' | 'populateTransaction';
type EventKeys = 'emit' | 'filters' | 'listenerCount' | 'listeners' | 'off' | 'on' | 'once' | 'queryFilter' | 'removeAllListeners' | 'removeListener';
type BaseContract<TContract extends Record<keyof Pick<Contract$2, PropertyKeys | FunctionKeys | EventKeys>, unknown>> = Omit<Contract$2, PropertyKeys | FunctionKeys | EventKeys> & TContract;
type InterfaceKeys = 'events' | 'functions';
type BaseInterface<Interface extends Record<keyof Pick<ethers.utils.Interface, InterfaceKeys>, unknown>> = Omit<ethers.utils.Interface, InterfaceKeys> & Interface;
type Contract<TAbi extends Abi, _Functions = Functions<TAbi>> = _Functions & BaseContract<{
    address: Address;
    resolvedAddress: Promise<Address>;
    attach(addressOrName: Address | string): Contract<TAbi>;
    connect(signerOrProvider: ethers.Signer | ethers.providers.Provider | string): Contract<TAbi>;
    deployed(): Promise<Contract<TAbi>>;
    interface: BaseInterface<{
        events: InterfaceEvents<TAbi>;
        functions: InterfaceFunctions<TAbi>;
    }>;
    callStatic: _Functions;
    estimateGas: Functions<TAbi, {
        ReturnType: ResolvedConfig['BigIntType'];
    }>;
    functions: Functions<TAbi, {
        ReturnTypeAsArray: true;
    }>;
    populateTransaction: Functions<TAbi, {
        ReturnType: ethers.PopulatedTransaction;
    }>;
    emit<TEventName extends ExtractAbiEventNames<TAbi> | ethers.EventFilter>(eventName: TEventName, ...args: AbiParametersToPrimitiveTypes<ExtractAbiEvent<TAbi, TEventName extends string ? TEventName : ExtractAbiEventNames<TAbi>>['inputs']> extends infer TArgs extends readonly unknown[] ? TArgs : never): boolean;
    filters: Filters<TAbi>;
    listenerCount(): number;
    listenerCount<TEventName extends ExtractAbiEventNames<TAbi>>(eventName: TEventName): number;
    listenerCount(eventFilter: ethers.EventFilter): number;
    listeners(): Array<(...args: any[]) => void>;
    listeners<TEventName extends ExtractAbiEventNames<TAbi>>(eventName: TEventName): Array<Listener<TAbi, TEventName>>;
    listeners(eventFilter: ethers.EventFilter): Array<Listener<TAbi, ExtractAbiEventNames<TAbi>>>;
    off: EventListener<TAbi>;
    on: EventListener<TAbi>;
    once: EventListener<TAbi>;
    queryFilter<TEventName extends ExtractAbiEventNames<TAbi>>(event: TEventName, fromBlockOrBlockhash?: string | number, toBlock?: string | number): Promise<Array<ethers.Event>>;
    queryFilter(eventFilter: ethers.EventFilter, fromBlockOrBlockhash?: string | number, toBlock?: string | number): Promise<Array<ethers.Event>>;
    removeAllListeners(eventName?: ExtractAbiEventNames<TAbi>): Contract<TAbi>;
    removeAllListeners(eventFilter: ethers.EventFilter): Contract<TAbi>;
    removeListener: EventListener<TAbi>;
}>;
type Functions<TAbi extends Abi, Options extends {
    ReturnType?: any;
    ReturnTypeAsArray?: boolean;
} = {
    ReturnTypeAsArray: false;
}> = UnionToIntersection<{
    [K in keyof TAbi]: TAbi[K] extends infer TAbiFunction extends AbiFunction & {
        type: 'function';
    } ? {
        [K in CountOccurrences<TAbi, {
            name: TAbiFunction['name'];
        }> extends 1 ? AbiItemName<TAbiFunction> : AbiItemName<TAbiFunction, true>]: (...args: [
            ...args: TAbiFunction['inputs'] extends infer TInputs extends readonly AbiParameter[] ? AbiParametersToPrimitiveTypes<TInputs> : never,
            overrides?: GetOverridesForAbiStateMutability<TAbiFunction['stateMutability']>
        ]) => Promise<IsUnknown<Options['ReturnType']> extends true ? AbiFunctionReturnType<TAbiFunction> extends infer TAbiFunctionReturnType ? Options['ReturnTypeAsArray'] extends true ? [TAbiFunctionReturnType] : TAbiFunctionReturnType : never : Options['ReturnType']>;
    } : never;
}[number]>;
type AbiFunctionReturnType<TAbiFunction extends AbiFunction & {
    type: 'function';
}> = ({
    payable: ethers.ContractTransaction;
    nonpayable: ethers.ContractTransaction;
} & {
    [_ in 'pure' | 'view']: TAbiFunction['outputs']['length'] extends infer TLength ? TLength extends 0 ? void : TLength extends 1 ? AbiParameterToPrimitiveType<TAbiFunction['outputs'][0]> : {
        [Output in TAbiFunction['outputs'][number] as Output extends {
            name: string;
        } ? Output['name'] extends '' ? never : Output['name'] : never]: AbiParameterToPrimitiveType<Output>;
    } & AbiParametersToPrimitiveTypes<TAbiFunction['outputs']> : never;
})[TAbiFunction['stateMutability']];
type InterfaceFunctions<TAbi extends Abi> = UnionToIntersection<{
    [K in keyof TAbi]: TAbi[K] extends infer TAbiFunction extends AbiFunction & {
        type: 'function';
    } ? {
        [K in AbiItemName<TAbiFunction, true>]: ethers.utils.FunctionFragment;
    } : never;
}[number]>;
type InterfaceEvents<TAbi extends Abi> = UnionToIntersection<{
    [K in keyof TAbi]: TAbi[K] extends infer TAbiEvent extends AbiEvent ? {
        [K in AbiItemName<TAbiEvent, true>]: ethers.utils.EventFragment;
    } : never;
}[number]>;
interface EventListener<TAbi extends Abi> {
    <TEventName extends ExtractAbiEventNames<TAbi>>(eventName: TEventName, listener: Listener<TAbi, TEventName>): Contract<TAbi>;
    (eventFilter: ethers.EventFilter, listener: Listener<TAbi, ExtractAbiEventNames<TAbi>>): Contract<TAbi>;
}
type Listener<TAbi extends Abi, TEventName extends string, TAbiEvent extends AbiEvent = ExtractAbiEvent<TAbi, TEventName>> = AbiParametersToPrimitiveTypes<TAbiEvent['inputs']> extends infer TArgs extends readonly unknown[] ? (...args: [...args: TArgs, event: Event<TAbiEvent>]) => void : never;
type Filters<TAbi extends Abi> = UnionToIntersection<{
    [K in keyof TAbi]: TAbi[K] extends infer TAbiEvent extends AbiEvent ? {
        [K in CountOccurrences<TAbi, {
            name: TAbiEvent['name'];
        }> extends 1 ? AbiItemName<TAbiEvent> : AbiItemName<TAbiEvent, true>]: (...args: TAbiEvent['inputs'] extends infer TAbiParameters extends readonly (AbiParameter & {
            indexed?: boolean;
        })[] ? {
            [K in keyof TAbiParameters]: TAbiParameters[K]['indexed'] extends true ? AbiParameterToPrimitiveType<TAbiParameters[K]> | null : null;
        } : never) => ethers.EventFilter;
    } : never;
}[number]>;

export { Contract$1 as C, EventListener as E, GetConfig as G, Overrides as O, PayableOverrides as P, GetOverridesForAbiStateMutability as a, ContractsConfig as b, ContractsResult as c, GetReturnType as d, GetFunctionName as e, GetArgs as f, getContract as g, GetContractArgs as h, GetContractResult as i, CallOverrides as j };
